from datetime import datetime
from enum import Enum
from pydantic import BaseModel, field_validator


#Роли и статусы

class Role(str, Enum):
    director      = "director"
    senior_seller = "senior_seller"
    seller        = "seller"


class TaskStatus(str, Enum):
    new         = "new"
    in_progress = "in_progress"
    done        = "done"


#Auth

class LoginRequest(BaseModel):
    username: str
    password: str

    @field_validator("username")
    @classmethod
    def username_strip(cls, v: str) -> str:
        return v.strip()


class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


#Пользователи

class UserCreate(BaseModel):
    username: str
    password: str
    role:     Role

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Пароль минимум 8 символов")
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Пароль слишком длинный (максимум 72 байта)")
        return v

    @field_validator("username")
    @classmethod
    def username_valid(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Логин минимум 3 символа")
        return v


class UserOut(BaseModel):
    id:         int
    username:   str
    role:       Role
    is_active:  bool
    created_at: datetime


#задачи 

class TaskCreate(BaseModel):
    title:       str
    description: str | None = None
    assignee_id: int

    @field_validator("title")
    @classmethod
    def title_valid(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Название минимум 3 символа")
        return v


class TaskStatusUpdate(BaseModel):
    status: TaskStatus


class TaskOut(BaseModel):
    id:          int
    title:       str
    description: str | None
    status:      TaskStatus
    creator_id:  int
    assignee_id: int
    created_at:  datetime
    updated_at:  datetime