# Django + PostgreSQL in a single container for Cloud Run
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DB_NAME=teamtasks \
    DB_USER=postgres \
    DB_PASSWORD= \
    DB_HOST=127.0.0.1 \
    DB_PORT=5432

WORKDIR /app

# Install PostgreSQL server + client
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql postgresql-client libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Allow password-free local connections (container-only, not exposed)
RUN echo "local all all trust" > /etc/postgresql/15/main/pg_hba.conf && \
    echo "host all all 127.0.0.1/32 trust" >> /etc/postgresql/15/main/pg_hba.conf && \
    echo "host all all ::1/128 trust" >> /etc/postgresql/15/main/pg_hba.conf

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
