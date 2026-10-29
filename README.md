# Render Watcher

An Android app with an AI agent that watches your [Render](https://render.com) services and pings you when something actually breaks.

The agent reads your services' logs every minute, groups errors into incidents, asks Gemini what went wrong, and sends a push notification only when it's confident enough. Every decision it makes is logged, with the log lines it based the call on.

**[Download the latest APK →](https://github.com/debayudh07/cludvex/releases/latest)**

## Features

- **Sign in with GitHub**, connect a Render API key, and pick up to 3 services to watch
- **Incident grouping:** repeated errors within a 10-minute window become one incident, not a flood of alerts
- **AI triage with a second opinion:** Gemini diagnoses each incident, and an optional verifier pass checks the diagnosis
- **Confidence gate:** you set how sure the agent must be (50–95%) before it states an alert as fact. Anything below the gate is marked "needs review"
- **Mandate controls:** max alerts per hour, quiet hours (critical alerts still get through), and line grouping
- **Live log stream** over WebSocket, alert history, and an activity feed of everything the agent did
- **Auto-resolve:** alerts close themselves after an incident stops recurring for 30 minutes
- **Notify-only by default:** the agent never restarts or changes your services. A user-tapped Restart exists behind a server flag

## How it works

```
Render API ──logs──▶ Watcher ──▶ filter & group ──▶ Gemini triage ──▶ verifier ──▶ confidence gate
                        │                                                              │
                        ▼                                                              ▼
                    Firestore ◀──────────────── alerts, incidents, activity ───── FCM push
                        ▲
                        │
Flutter app ──HTTPS / WSS──▶ FastAPI
```

| Part | Stack | Path |
|---|---|---|
| Mobile app | Flutter, Firebase Auth (GitHub), Firebase Cloud Messaging | [`render_watcher/`](render_watcher/) |
| API | FastAPI, uvicorn | [`backend/app/main.py`](backend/app/main.py) |
| Watcher (agent) | asyncio loop, Gemini via `google-genai` | [`backend/app/watcher.py`](backend/app/watcher.py) |
| Storage | Cloud Firestore. Render API keys are encrypted with Fernet | [`backend/app/store.py`](backend/app/store.py) |

The watcher leases services from Firestore, so several watcher processes can run without double-processing.

## Running locally

### Backend

Requires Python 3.12+ and a Firebase project with Firestore, Authentication (GitHub provider) and Cloud Messaging enabled.

```bash
cd backend
cp .env.example .env        # then fill in the required values
python -m venv .venv && .venv/Scripts/activate   # Windows; use bin/activate elsewhere
pip install -e ".[dev]"

uvicorn app.main:app --port 8080   # API
python -m app.watcher              # watcher, in a second terminal
pytest                             # tests
```

Or with Docker: `docker compose up --build`. This exposes the API on port 8090 and runs the watcher as its own container. To work offline against the Firestore emulator, use `docker compose --profile emulator up`.

Deploy the Firestore indexes and rules once per project:

```bash
firebase deploy --only firestore:indexes,firestore:rules
```

### Required environment variables

| Variable | What it is |
|---|---|
| `FIREBASE_PROJECT_ID` | Your Firebase project ID |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Service-account JSON on one line. Needs the Cloud Datastore User and Firebase Cloud Messaging Admin roles |
| `ENCRYPTION_KEY` | Fernet key: `python -c "from cryptography.fernet import Fernet;print(Fernet.generate_key().decode())"`. The API and the watcher must use the same key |
| `GEMINI_API_KEY` | Google AI Studio API key |

All optional settings (poll interval, models, limits) are documented in [`backend/.env.example`](backend/.env.example).

### App

Requires Flutter 3.x and an Android device or emulator.

```bash
cd render_watcher
flutter run                                                  # uses the hosted backend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # local backend from the emulator
flutter build apk --release
```

## Deploying to Render

[`render.yaml`](render.yaml) is a Render Blueprint for the API, built from the root [`Dockerfile`](Dockerfile). On Render's free plan, set `RUN_WATCHER_IN_API=true`. The watcher then runs inside the API process and pings the service's own URL so it doesn't sleep.

For better resilience, run the watcher somewhere other than Render (for example a small VM with `docker compose up -d watcher`). Then it keeps alerting during a Render outage. If you do that, set `RUN_WATCHER_IN_API=false` so only one watcher polls.

Keep `WATCH_POLL_SECONDS` at 60 or higher to stay within Firestore's free tier.

## API

All endpoints except `/healthz` require a Firebase ID token (`Authorization: Bearer <token>`).

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/healthz` | Liveness and Firestore check |
| `GET` | `/me` | Current user and connection status |
| `POST` / `DELETE` | `/render/connect` | Save or remove the Render API key |
| `GET` | `/services` | Render services on the account |
| `PUT` | `/services/watched` | Choose which services to watch |
| `GET` / `PUT` | `/mandate` | Confidence gate, alert limits, quiet hours |
| `POST` / `DELETE` | `/devices` | Register a device for push notifications |
| `GET` | `/overview` | Dashboard summary |
| `GET` | `/alerts`, `/alerts/{id}` | Alert list and detail |
| `POST` | `/alerts/{id}/ignore` · `unignore` · `silence` | Triage actions |
| `POST` | `/alerts/{id}/restart` | Restart the service (only when `ACTIONS_ENABLED=true`) |
| `GET` | `/activity` | Agent activity feed |
| `WS` | `/logs/stream` | Live log stream |
