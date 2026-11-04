FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN pip install --no-cache-dir uv \
    && uv sync --locked --no-dev --no-install-project

COPY src ./src
COPY public/data ./public/data

ENV PYTHONPATH=/app/src \
    PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["uv", "run", "--no-sync", "litestar", "--app-dir", "src", "--app", "bible:app", "run", "--host", "0.0.0.0", "--port", "8000"]
