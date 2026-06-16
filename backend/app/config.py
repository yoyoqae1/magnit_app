from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    DATABASE_URL: str = "magnit.db"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache          #читаем .env только один раз, потом из кэша
def get_settings() -> Settings:
    return Settings()


settings = get_settings()