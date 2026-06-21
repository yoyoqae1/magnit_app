from fastapi import APIRouter, HTTPException, status, Depends

from app.database import get_db
from app.models import UserCreate, UserOut
from app.security import hash_password
from app.dependencies import get_current_user, require_role

router = APIRouter(prefix="/users", tags=["users"])


@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(
    body: UserCreate,
    current_user: dict = Depends(require_role("director")),  # только директор
):
    """Создать нового сотрудника. Только директор."""
    with get_db() as conn:
        # проверяем что такой логин не занят
        exists = conn.execute(
            "SELECT id FROM users WHERE username = ?", (body.username,)
        ).fetchone()
        if exists:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Пользователь с таким логином уже существует",
            )

        cursor = conn.execute(
            """
            INSERT INTO users (username, hashed_password, role)
            VALUES (?, ?, ?)
            """,
            (body.username, hash_password(body.password), body.role),
        )
        row = conn.execute(
            "SELECT id, username, role, is_active, created_at FROM users WHERE id = ?",
            (cursor.lastrowid,),
        ).fetchone()

    return dict(row)


@router.get("", response_model=list[UserOut])
def list_users(
    current_user: dict = Depends(require_role("director", "senior_seller")),
):
    """
    Список сотрудников.
    Директор видит всех.
    Старший продавец видит только продавцов (т.к. может назначать задачи только им).
    """
    with get_db() as conn:
        if current_user["role"] == "director":
            rows = conn.execute(
                "SELECT id, username, role, is_active, created_at FROM users ORDER BY id"
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT id, username, role, is_active, created_at FROM users WHERE role = 'seller' ORDER BY id"
            ).fetchall()
    return [dict(r) for r in rows]

@router.patch("/{user_id}/deactivate", response_model=UserOut)
def deactivate_user(
    user_id: int,
    current_user: dict = Depends(require_role("director")),
):
    """Заблокировать сотрудника. Только директор."""
    if user_id == current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя заблокировать самого себя",
        )
    with get_db() as conn:
        row = conn.execute("SELECT id FROM users WHERE id = ?", (user_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                                detail="Пользователь не найден")
        conn.execute("UPDATE users SET is_active = 0 WHERE id = ?", (user_id,))
        # отзываем все токены заблокированного
        conn.execute(
            "UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?", (user_id,)
        )
        row = conn.execute(
            "SELECT id, username, role, is_active, created_at FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
    return dict(row)