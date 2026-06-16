from fastapi import APIRouter, HTTPException, status, Depends

from app.database import get_db
from app.models import TaskCreate, TaskOut, TaskStatusUpdate, Role
from app.dependencies import get_current_user, require_role

router = APIRouter(prefix="/tasks", tags=["tasks"])


def _can_assign(creator_role: str, assignee_role: str) -> bool:
    """Проверяет может ли создатель назначить задачу этому сотруднику."""
    if creator_role == Role.director:
        return True  # директор назначает всем
    if creator_role == Role.senior_seller:
        return assignee_role == Role.seller  # старший — только продавцам
    return False  # продавец не может создавать задачи


@router.post("", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(
    body: TaskCreate,
    current_user: dict = Depends(require_role("director", "senior_seller")),
):
    """Создать задачу. Директор или старший продавец."""
    with get_db() as conn:
        # получаем роль исполнителя
        assignee = conn.execute(
            "SELECT id, role, is_active FROM users WHERE id = ?", (body.assignee_id,)
        ).fetchone()

        if not assignee:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                                detail="Исполнитель не найден")

        if not assignee["is_active"]:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
                                detail="Нельзя назначить задачу заблокированному сотруднику")

        if not _can_assign(current_user["role"], assignee["role"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail="Недостаточно прав для назначения этому сотруднику")

        cursor = conn.execute(
            """
            INSERT INTO tasks (title, description, creator_id, assignee_id)
            VALUES (?, ?, ?, ?)
            """,
            (body.title, body.description, current_user["user_id"], body.assignee_id),
        )
        row = conn.execute(
            "SELECT * FROM tasks WHERE id = ?", (cursor.lastrowid,)
        ).fetchone()

    return dict(row)


@router.get("", response_model=list[TaskOut])
def list_tasks(current_user: dict = Depends(get_current_user)):
    """
    Список задач:
    - директор видит все
    - старший продавец видит все
    - продавец видит только свои
    """
    with get_db() as conn:
        if current_user["role"] in (Role.director, Role.senior_seller):
            rows = conn.execute(
                "SELECT * FROM tasks ORDER BY created_at DESC"
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM tasks WHERE assignee_id = ? ORDER BY created_at DESC",
                (current_user["user_id"],),
            ).fetchall()

    return [dict(r) for r in rows]


@router.get("/{task_id}", response_model=TaskOut)
def get_task(task_id: int, current_user: dict = Depends(get_current_user)):
    """Получить одну задачу."""
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM tasks WHERE id = ?", (task_id,)
        ).fetchone()

    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Задача не найдена")

    task = dict(row)

    # продавец может видеть только свои задачи
    if (current_user["role"] == Role.seller
            and task["assignee_id"] != current_user["user_id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                            detail="Нет доступа к этой задаче")

    return task


@router.patch("/{task_id}/status", response_model=TaskOut)
def update_status(
    task_id: int,
    body: TaskStatusUpdate,
    current_user: dict = Depends(get_current_user),
):
    """
    Изменить статус задачи.
    Продавец — только своих задач.
    Директор и старший — любых.
    """
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM tasks WHERE id = ?", (task_id,)
        ).fetchone()

        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                                detail="Задача не найдена")

        task = dict(row)

        if (current_user["role"] == Role.seller
                and task["assignee_id"] != current_user["user_id"]):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail="Нельзя менять статус чужой задачи")

        conn.execute(
            "UPDATE tasks SET status = ? WHERE id = ?",
            (body.status, task_id),
        )
        row = conn.execute(
            "SELECT * FROM tasks WHERE id = ?", (task_id,)
        ).fetchone()

    return dict(row)