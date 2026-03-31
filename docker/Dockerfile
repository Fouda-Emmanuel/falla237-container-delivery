# STAGE 1 : BUILD STAGE
FROM python:3.13-slim AS builder

LABEL maintainer="Fouda Aime Emmanuel Kalvin" \
      project="Falla237"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential libpq-dev curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --upgrade pip && \
    pip install --user --no-cache-dir -r requirements.txt

COPY . .

# Stage 2 : RUNTIME STAGE
FROM python:3.13-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/home/django-user/.local/bin:$PATH"

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 && \
    useradd -m django-user && \
    rm -rf /var/lib/apt/lists/* 

COPY --from=builder /root/.local /home/django-user/.local

COPY --from=builder --chown=django-user:django-user /app /app

COPY --chown=django-user:django-user docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /app/staticfiles /app/media  && \
    chown -R django-user:django-user /app/staticfiles /app/media 

USER django-user

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "falla_proj.wsgi:application"]
