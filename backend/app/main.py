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
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(tasks.router)


@app.get("/health")
def health():
    return {"status": "ok"}