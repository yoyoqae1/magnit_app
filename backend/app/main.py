from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, users, tasks

app = FastAPI(
    title="Magnit Task Manager",
    version="1.0.0",
    docs_url="/docs",       
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://89.125.120.6",
        "https://89.125.120.6",
    ],
    allow_methods=["GET", "POST", "PATCH"],  # только нужные методы
    allow_headers=["Authorization", "Content-Type"],
    allow_credentials=False,
)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(tasks.router)


@app.get("/health")
def health():
    return {"status": "ok"}