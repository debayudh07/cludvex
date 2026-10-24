from fastapi import Depends, HTTPException, status

from .firebase import db
from .models import RenderConnection
from .render_client import RenderClient
from .security import CurrentUser, current_user, decrypt_secret
from .store import Store


def get_store() -> Store:
    return Store(db())


def render_factory():
    """Overridable in tests."""
    return RenderClient


async def user_ctx(user: CurrentUser = Depends(current_user), store: Store = Depends(get_store)):
    await store.upsert_user(user.uid, user.email, user.github_login)
    return user


async def render_conn(user: CurrentUser = Depends(user_ctx), store: Store = Depends(get_store)) -> RenderConnection:
    conn = await store.get_render(user.uid)
    if conn is None:
        raise HTTPException(status.HTTP_409_CONFLICT, "Render is not connected")
    return conn


def render_key(conn: RenderConnection) -> str:
    return decrypt_secret(conn.encrypted_key)
