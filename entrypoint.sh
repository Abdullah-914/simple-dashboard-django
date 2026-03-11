#!/bin/bash
set -e

# Start PostgreSQL
pg_ctlcluster 15 main start

# Wait for PostgreSQL to accept connections
until pg_isready -h 127.0.0.1 -U postgres > /dev/null 2>&1; do
  sleep 1
done

# Create database if it doesn't exist (first boot)
su - postgres -c "psql -tc \"SELECT 1 FROM pg_database WHERE datname='teamtasks'\"" | grep -q 1 || \
  su - postgres -c "createdb teamtasks"

# Run Django setup
python manage.py migrate --noinput
python manage.py collectstatic --noinput 2>/dev/null || true

# Create superuser if env vars are provided
if [ -n "$DJANGO_SUPERUSER_USERNAME" ]; then
  python manage.py createsuperuser --noinput 2>/dev/null || true
fi

# Start gunicorn on Cloud Run's PORT (default 8080)
exec gunicorn config.wsgi:application \
  --bind "0.0.0.0:${PORT:-8080}" \
  --workers 2 \
  --threads 4 \
  --timeout 120
