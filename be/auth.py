"""Auth: hash password sederhana (sha256) + JWT."""
from __future__ import annotations

import hashlib
import os
from datetime import datetime, timedelta, timezone

import jwt

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-ganti-di-production")
ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = int(os.getenv("TOKEN_EXPIRE_HOURS", "12"))


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def verify_password(password: str, stored: str) -> bool:
    """Mock menyimpan plaintext, DB asli menyimpan sha256 hex."""
    if not stored:
        return False
    # mock: stored berupa plaintext ("admin123")
    if stored == password:
        return True
    # real: stored berupa sha256 hex (64 char hex)
    try:
        return hash_password(password) == stored
    except Exception:
        return False


def create_token(user: dict) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user["id"]),
        "username": user["username"],
        "role": user.get("role", "member"),
        "full_name": user.get("full_name", ""),
        "iat": now,
        "exp": now + timedelta(hours=TOKEN_EXPIRE_HOURS),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
