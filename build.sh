#!/usr/bin/env bash
# Build script for Render deployment
set -o errexit

# 1. Install Python dependencies
pip install --upgrade pip
pip install -r requirements.txt

# 2. Build React frontend
cd frontend
npm ci
npm run build
cd ..

# 3. Copy React index.html to a Django templates directory
mkdir -p templates
cp frontend/dist/index.html templates/index.html

# 4. Collect Django static files (includes React build via whitenoise)
python manage.py collectstatic --noinput

# 5. Run database migrations
python manage.py migrate --noinput

# 6. Create superuser (only on first deploy, silently skips if exists)
python manage.py createsuperuser --noinput 2>/dev/null || true
