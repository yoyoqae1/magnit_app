import bcrypt
import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

from app.config import settings

# Cost factor 12 — стандарт для bcrypt на 2026 год: достаточно медленно
# для защиты от brute-force, но не убивает время ответа сервера
_BCRYPT_ROUNDS = 12
_MAX_PASSWORD_BYTES = 72  # bcrypt физически не использует байты после 72-го


# ─── Пароли ───────────────────────────────────────────────────

def hash_password(plain: str) -> str:
    password_bytes = plain.encode("utf-8")
    if len(password_bytes) > _MAX_PASSWORD_BYTES:
        # Лучше явно отказать, чем тихо обрезать пароль —
        # тихое обрезание создаёт нелогичное поведение
        # ("123...очень длинный" и "123...очень длинный2" дают один хэш)
        raise ValueError("Пароль не должен превышать 72 байта")
    salt = bcrypt.gensalt(rounds=_BCRYPT_ROUNDS)
    hashed = bcrypt.hashpw(password_bytes, salt)
    return hashed.decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        # Битый/несовместимый хэш в БД не должен ронять запрос 500-й ошибкой —
        # это просто означает "пароль неверный"
        return False


# ─── Access Token (JWT) ────────────────────────────────────────

def create_access_token(user_id: int, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "sub": str(user_id),
        "role": role,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    """Возвращает payload или бросает JWTError."""
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    if payload.get("type") != "access":
        raise JWTError("Wrong token type")
    return payload


# ─── Refresh Token ─────────────────────────────────────────────

def generate_refresh_token() -> tuple[str, str]:
    """Возвращает (сырой токен для клиента, хэш для БД)."""
    raw = secrets.token_urlsafe(64)
    token_hash = hashlib.sha256(raw.encode()).hexdigest()
    return raw, token_hash


def hash_refresh_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()