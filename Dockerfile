# Repo-root build of backend/ for Render, which looks for ./Dockerfile by
# default. Keep in sync with backend/Dockerfile (used by docker compose).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv

COPY backend/pyproject.toml ./
COPY backend/app ./app
RUN pip install --no-cache-dir . && useradd -r -u 10001 app
USER app

EXPOSE 8080
# Render injects PORT; fall back to 8080 elsewhere.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --proxy-headers"]
