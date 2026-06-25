from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, status

from app.database import get_db
from app.models import LoginRequest, RefreshRequest, TokenResponse
from app.security import (
    create_access_token,
    generate_refresh_token,
    hash_refresh_token,
    hash_password,
    verify_password,
)
from app.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


def _save_refresh_token(conn, user_id: int, token_hash: str) -> None:
    expires = datetime.now(timezone.utc) + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    conn.execute(
        """
        INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
        VALUES (?, ?, ?)
        """,
        (user_id, token_hash, expires.isoformat()),
    )


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest):
    with get_db() as conn:
        row = conn.execute(
            "SELECT id, hashed_password, role, is_active FROM users WHERE username = ?",
            (body.username,),
        ).fetchone()

        # одинаковое сообщение — не раскрываем существует ли пользователь
        if not row or not verify_password(body.password, row["hashed_password"]):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Неверный логин или пароль",
            )

        if not row["is_active"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Аккаунт заблокирован",
            )

        access  = create_access_token(row["id"], row["role"])
        raw, token_hash = generate_refresh_token()
        _save_refresh_token(conn, row["id"], token_hash)

    return TokenResponse(access_token=access, refresh_token=raw)


@router.post("/refresh", response_model=TokenResponse)
def refresh(body: RefreshRequest):
    token_hash = hash_refresh_token(body.refresh_token)

    with get_db() as conn:
        row = conn.execute(
            """
            SELECT rt.id, rt.user_id, rt.expires_at, rt.revoked,
                   u.role, u.is_active
            FROM refresh_tokens rt
            JOIN users u ON u.id = rt.user_id
            WHERE rt.token_hash = ?
            """,
            (token_hash,),
        ).fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                                detail="Токен не найден")

        if expires_at < now:
            raise 401

        if row["revoked"]:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Токен уже использован",
            )

        expires_at = datetime.fromisoformat(row["expires_at"])
        if expires_at < datetime.now(timezone.utc):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                                detail="Токен истёк")

        if not row["is_active"]:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail="Аккаунт заблокирован")

        #Rotate: старый отзываем, выдаём новый
        conn.execute(
            "UPDATE refresh_tokens SET revoked = 1 WHERE id = ?",
            (row["id"],),
        )

        access = create_access_token(row["user_id"], row["role"])
        raw, new_hash = generate_refresh_token()
        _save_refresh_token(conn, row["user_id"], new_hash)

    return TokenResponse(access_token=access, refresh_token=raw)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(body: RefreshRequest):
    token_hash = hash_refresh_token(body.refresh_token)
    with get_db() as conn:
        conn.execute(
            "UPDATE refresh_tokens SET revoked = 1 WHERE token_hash = ?",
            (token_hash,),
        )