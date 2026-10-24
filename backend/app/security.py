from dataclasses import dataclass

from cryptography.fernet import Fernet, InvalidToken
from fastapi import Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth

from .config import get_settings
from .firebase import firebase_app

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    uid: str
    email: str | None
    github_login: str | None


async def verify_token(token: str) -> CurrentUser:
    try:
        claims = await run_in_threadpool(auth.verify_id_token, token, firebase_app())
    except Exception as e:  # invalid, expired or revoked
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token") from e
    identities = claims.get("firebase", {}).get("identities", {})
    gh = identities.get("github.com") or []
    return CurrentUser(
        uid=claims["uid"],
        email=claims.get("email"),
        github_login=claims.get("name") or (gh[0] if gh else None),
    )


async def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> CurrentUser:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    return await verify_token(creds.credentials)


def _fernet() -> Fernet:
    return Fernet(get_settings().encryption_key.encode())


def encrypt_secret(value: str) -> str:
    return _fernet().encrypt(value.encode()).decode()


def decrypt_secret(token: str) -> str:
    try:
        return _fernet().decrypt(token.encode()).decode()
    except InvalidToken as e:
        raise RuntimeError("Stored Render key cannot be decrypted; was ENCRYPTION_KEY rotated?") from e
