from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    log_level: str = "INFO"

    # Firebase / Firestore
    firebase_project_id: str
    firebase_service_account_json: str | None = None  # raw JSON; else GOOGLE_APPLICATION_CREDENTIALS
    firestore_emulator_host: str | None = None

    # Render API keys are encrypted at rest with this Fernet key.
    encryption_key: str

    # Gemini
    gemini_api_key: str
    # Pinned rather than the *-latest aliases: both calls use a response_schema,
    # and an alias silently moving to a new model can change structured output.
    triage_model: str = "gemini-3.8-flash"
    verifier_model: str = "gemini-3.8-flash"

    render_api_base: str = "https://api.render.com/v1"

    # v1 is notify-only. Restart exists but is refused unless this is true.
    actions_enabled: bool = False

    # 15s against cloud Firestore exceeds the free tier at 2+ watched
    # services (~5 reads + 2 writes per service per cycle). 60s keeps
    # 3 services near 21k reads / 9k writes a day.
    watch_poll_seconds: int = 60
    group_window_seconds: int = 600
    resolve_after_minutes: int = 30
    max_watched_services: int = 3
    default_confidence_gate: int = 75
    default_max_alerts_per_hour: int = 6

    # Free-tier hosting: run the watcher loop inside the API process. Render
    # free web services sleep after 15 min without inbound traffic, so the
    # API also pings its own public URL (Render sets RENDER_EXTERNAL_URL).
    run_watcher_in_api: bool = False
    render_external_url: str | None = None
    keepalive_seconds: int = 600

    @property
    def render_ws_base(self) -> str:
        return self.render_api_base.replace("https://", "wss://").replace("http://", "ws://")


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
