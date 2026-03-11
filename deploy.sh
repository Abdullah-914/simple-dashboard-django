#!/bin/bash
# ============================================================
# deploy.sh — Deploy to Google Cloud (Cloud Run + Firebase)
#
# Architecture:
#   React Frontend  → Firebase Hosting (free)
#   Django Backend   → Cloud Run (container)
#   PostgreSQL       → Inside the container (no Cloud SQL)
#
# Prerequisites:
#   1. Google Cloud SDK (gcloud) — authenticated
#   2. Node.js & npm
#
# Usage:
#   export GCP_PROJECT_ID="your-project-id"
#   chmod +x deploy.sh && ./deploy.sh
# ============================================================

set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID env var}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="team-task-manager"

echo "================================================="
echo "  Deploying to GCP: $PROJECT_ID ($REGION)"
echo "  Backend:  Cloud Run ($SERVICE_NAME)"
echo "  Frontend: Firebase Hosting"
echo "  Database: PostgreSQL (in-container)"
echo "================================================="

# ── 1. Set project & enable APIs ────────────────────────────
echo ""
echo "[1/6] Setting project and enabling APIs..."
gcloud config set project "$PROJECT_ID"
gcloud services enable \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    firebasehosting.googleapis.com

# ── 2. Create Artifact Registry repo ────────────────────────
echo ""
echo "[2/6] Setting up Artifact Registry..."
if ! gcloud artifacts repositories describe "$SERVICE_NAME" --location="$REGION" &>/dev/null; then
    gcloud artifacts repositories create "$SERVICE_NAME" \
        --repository-format=docker \
        --location="$REGION"
fi

# ── 3. Build & deploy to Cloud Run ──────────────────────────
echo ""
echo "[3/6] Building container and deploying to Cloud Run..."
IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}:latest"
SECRET_KEY=$(openssl rand -base64 50 | tr -d '\n')

gcloud builds submit --tag "$IMAGE_URL" .

SERVICE_URL=$(gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_URL" \
    --region "$REGION" \
    --platform managed \
    --allow-unauthenticated \
    --port 8080 \
    --memory 512Mi \
    --min-instances 0 \
    --max-instances 4 \
    --set-env-vars "DEBUG=False" \
    --set-env-vars "SECRET_KEY=$SECRET_KEY" \
    --set-env-vars "ALLOWED_HOSTS=.run.app,.web.app,.firebaseapp.com,localhost" \
    --set-env-vars "DJANGO_SUPERUSER_USERNAME=admin" \
    --set-env-vars "DJANGO_SUPERUSER_EMAIL=admin@example.com" \
    --set-env-vars "DJANGO_SUPERUSER_PASSWORD=admin123" \
    --format "value(status.url)")

SERVICE_URL=$(echo "$SERVICE_URL" | tr -d '[:space:]')
echo "  Cloud Run URL: $SERVICE_URL"

FIREBASE_URL="https://${PROJECT_ID}.web.app"
gcloud run services update "$SERVICE_NAME" \
    --region "$REGION" \
    --update-env-vars "CORS_ALLOWED_ORIGIN=$FIREBASE_URL" \
    --update-env-vars "CSRF_TRUSTED_ORIGIN=$FIREBASE_URL"

# ── 4. Build React frontend ─────────────────────────────────
echo ""
echo "[4/6] Building React frontend..."
cd frontend
npm ci
npm run build
cd ..

# ── 5. Add Firebase to project ──────────────────────────────
echo ""
echo "[5/6] Setting up Firebase..."
if ! command -v firebase &>/dev/null; then
    echo "  Installing Firebase CLI..."
    npm install -g firebase-tools
fi

firebase login --no-localhost 2>/dev/null || true
firebase projects:addfirebase "$PROJECT_ID" 2>/dev/null || true

# ── 6. Deploy frontend to Firebase Hosting ──────────────────
echo ""
echo "[6/6] Deploying frontend to Firebase Hosting..."
firebase deploy --only hosting --project "$PROJECT_ID"

echo ""
echo "================================================="
echo "  Deployment complete!"
echo ""
echo "  Frontend: $FIREBASE_URL"
echo "  Backend:  $SERVICE_URL"
echo "  Database: PostgreSQL (inside Cloud Run container)"
echo ""
echo "  Default admin account:"
echo "    Username: admin"
echo "    Password: admin123"
echo "    Admin panel: $FIREBASE_URL/admin/"
echo "================================================="
