#!/bin/bash
# ============================================================
# deploy.sh — Deploy Team Task Manager to Google Cloud Platform
#
# Prerequisites:
#   1. Google Cloud SDK (gcloud) installed and authenticated
#   2. A GCP project created
#   3. Billing enabled on the project
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
# ============================================================

set -euo pipefail

# ── Configuration (edit these) ──────────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:?Set GCP_PROJECT_ID env var}"
REGION="${GCP_REGION:-us-central1}"
SERVICE_NAME="team-task-manager"
DB_INSTANCE_NAME="team-task-db"
DB_NAME="teamtasks"
DB_USER="postgres"
DB_TIER="db-f1-micro"       # Free-tier eligible

echo "═══════════════════════════════════════════════"
echo "  Deploying to GCP Project: $PROJECT_ID"
echo "  Region: $REGION"
echo "═══════════════════════════════════════════════"

# ── 1. Set project & enable APIs ────────────────────────────
echo "→ Setting project and enabling APIs..."
gcloud config set project "$PROJECT_ID"
gcloud services enable \
    sqladmin.googleapis.com \
    run.googleapis.com \
    cloudbuild.googleapis.com \
    secretmanager.googleapis.com \
    artifactregistry.googleapis.com

# ── 2. Create Cloud SQL PostgreSQL instance ─────────────────
echo "→ Creating Cloud SQL instance (this may take a few minutes)..."
if ! gcloud sql instances describe "$DB_INSTANCE_NAME" --project="$PROJECT_ID" &>/dev/null; then
    gcloud sql instances create "$DB_INSTANCE_NAME" \
        --database-version=POSTGRES_15 \
        --tier="$DB_TIER" \
        --region="$REGION" \
        --storage-auto-increase \
        --availability-type=zonal
    echo "  Cloud SQL instance created."
else
    echo "  Cloud SQL instance already exists, skipping."
fi

# Set the postgres user password
DB_PASSWORD=$(openssl rand -base64 24)
gcloud sql users set-password "$DB_USER" \
    --instance="$DB_INSTANCE_NAME" \
    --password="$DB_PASSWORD"

# Create the database
if ! gcloud sql databases describe "$DB_NAME" --instance="$DB_INSTANCE_NAME" &>/dev/null; then
    gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE_NAME"
fi

# Get the connection name
CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE_NAME" --format="value(connectionName)")
echo "  Connection: $CONNECTION_NAME"

# ── 3. Store secrets in Secret Manager ──────────────────────
echo "→ Storing secrets..."
DJANGO_SECRET_KEY=$(openssl rand -base64 50 | tr -d '\n')

create_or_update_secret() {
    local name=$1 value=$2
    if gcloud secrets describe "$name" --project="$PROJECT_ID" &>/dev/null; then
        echo -n "$value" | gcloud secrets versions add "$name" --data-file=-
    else
        echo -n "$value" | gcloud secrets create "$name" --data-file=- --replication-policy=automatic
    fi
}

create_or_update_secret "django-secret-key" "$DJANGO_SECRET_KEY"
create_or_update_secret "db-password" "$DB_PASSWORD"

# ── 4. Build & push Docker image ────────────────────────────
echo "→ Building Docker image with Cloud Build..."
IMAGE_URL="${REGION}-docker.pkg.dev/${PROJECT_ID}/${SERVICE_NAME}/${SERVICE_NAME}:latest"

# Create Artifact Registry repo if it doesn't exist
if ! gcloud artifacts repositories describe "$SERVICE_NAME" --location="$REGION" &>/dev/null; then
    gcloud artifacts repositories create "$SERVICE_NAME" \
        --repository-format=docker \
        --location="$REGION"
fi

gcloud builds submit --tag "$IMAGE_URL" .

# ── 5. Deploy to Cloud Run ──────────────────────────────────
echo "→ Deploying to Cloud Run..."
SERVICE_URL_RAW=$(gcloud run deploy "$SERVICE_NAME" \
    --image "$IMAGE_URL" \
    --region "$REGION" \
    --platform managed \
    --allow-unauthenticated \
    --add-cloudsql-instances "$CONNECTION_NAME" \
    --port 8080 \
    --memory 512Mi \
    --min-instances 0 \
    --max-instances 4 \
    --set-env-vars "DEBUG=False" \
    --set-env-vars "DB_NAME=$DB_NAME" \
    --set-env-vars "DB_USER=$DB_USER" \
    --set-env-vars "DB_HOST=/cloudsql/$CONNECTION_NAME" \
    --set-env-vars "DB_PORT=5432" \
    --set-secrets "SECRET_KEY=django-secret-key:latest,DB_PASSWORD=db-password:latest" \
    --format "value(status.url)")

# Trim any trailing whitespace
SERVICE_URL=$(echo "$SERVICE_URL_RAW" | tr -d '[:space:]')

# Update ALLOWED_HOSTS, CORS, and CSRF with the Cloud Run URL
echo "→ Updating service with final origin settings..."
gcloud run services update "$SERVICE_NAME" \
    --region "$REGION" \
    --update-env-vars "ALLOWED_HOSTS=.run.app,localhost,127.0.0.1" \
    --update-env-vars "CORS_ALLOWED_ORIGIN=$SERVICE_URL" \
    --update-env-vars "CSRF_TRUSTED_ORIGIN=$SERVICE_URL"

# ── 6. Run migrations ───────────────────────────────────────
echo "→ Running database migrations..."
gcloud run jobs create migrate-db \
    --image "$IMAGE_URL" \
    --region "$REGION" \
    --set-cloudsql-instances "$CONNECTION_NAME" \
    --set-env-vars "DEBUG=False,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_HOST=/cloudsql/$CONNECTION_NAME,DB_PORT=5432" \
    --set-secrets "SECRET_KEY=django-secret-key:latest,DB_PASSWORD=db-password:latest" \
    --command "python" \
    --args "manage.py,migrate,--noinput" \
    2>/dev/null || true

gcloud run jobs execute migrate-db --region "$REGION" --wait

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✅ Deployment complete!"
echo ""
echo "  App URL: $SERVICE_URL"
echo "  Cloud SQL: $CONNECTION_NAME"
echo "  Database: $DB_NAME"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Create a superuser by running:"
echo "  gcloud run jobs create create-superuser \\"
echo "    --image $IMAGE_URL \\"
echo "    --region $REGION \\"
echo "    --set-cloudsql-instances $CONNECTION_NAME \\"
echo "    --set-env-vars \"DEBUG=False,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_HOST=/cloudsql/$CONNECTION_NAME,DB_PORT=5432,DJANGO_SUPERUSER_USERNAME=admin,DJANGO_SUPERUSER_EMAIL=admin@example.com,DJANGO_SUPERUSER_PASSWORD=changeme\" \\"
echo "    --set-secrets \"SECRET_KEY=django-secret-key:latest,DB_PASSWORD=db-password:latest\" \\"
echo "    --command python --args manage.py,createsuperuser,--noinput"
echo ""
echo "  Then execute: gcloud run jobs execute create-superuser --region $REGION --wait"
