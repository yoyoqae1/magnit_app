import sqlite3
from app.security import hash_password

conn = sqlite3.connect('magnit.db')
conn.execute(
    'INSERT INTO users (username, hashed_password, role) VALUES (?, ?, ?)',
    ('director1', hash_password('password123'), 'director')
)
conn.commit()
conn.close()
print('Пользователь создан!')