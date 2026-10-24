"""Single firebase-admin app shared by auth, FCM and Firestore."""

import json
import os
from functools import lru_cache

import firebase_admin
from firebase_admin import credentials, firestore_async
from google.cloud.firestore import AsyncClient

from .config import get_settings


@lru_cache
def firebase_app() -> firebase_admin.App:
    s = get_settings()
    if s.firestore_emulator_host:
        os.environ.setdefault("FIRESTORE_EMULATOR_HOST", s.firestore_emulator_host)
    if s.firebase_service_account_json:
        cred = credentials.Certificate(json.loads(s.firebase_service_account_json))
    elif os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"):
        cred = credentials.ApplicationDefault()
    else:
        cred = None  # emulator-only local dev
    return firebase_admin.initialize_app(cred, {"projectId": s.firebase_project_id})


@lru_cache
def db() -> AsyncClient:
    return firestore_async.client(firebase_app())
