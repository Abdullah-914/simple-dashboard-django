# ============================================================
# deploy.ps1 — Deploy Team Task Manager to Google Cloud Platform
#
# Prerequisites:
#   1. Google Cloud SDK (gcloud) installed and authenticated
#   2. A GCP project created & billing enabled
#
# Usage:
#   $env:GCP_PROJECT_ID = "your-project-id"
#   .\deploy.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# ── Configuration ───────────────────────────────────────────
$PROJECT_ID = $env:GCP_PROJECT_ID
if (-not $PROJECT_ID) { throw "Set GCP_PROJECT_ID env var first: `$env:GCP_PROJECT_ID = 'your-project-id'" }
$REGION       = if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }
$SERVICE_NAME = "team-task-manager"
$DB_INSTANCE  = "team-task-db"
$DB_NAME      = "teamtasks"
$DB_USER      = "postgres"
$DB_TIER      = "db-f1-micro"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Deploying to GCP Project: $PROJECT_ID"
Write-Host "  Region: $REGION"
Write-Host "=================================================" -ForegroundColor Cyan

# ── 1. Set project & enable APIs ────────────────────────────
Write-Host "`n-> Setting project and enabling APIs..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID
gcloud services enable sqladmin.googleapis.com run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com

# ── 2. Create Cloud SQL instance ────────────────────────────
Write-Host "`n-> Creating Cloud SQL PostgreSQL instance..." -ForegroundColor Yellow
$existing = gcloud sql instances list --filter="name=$DB_INSTANCE" --format="value(name)" 2>$null
if (-not $existing) {
    gcloud sql instances create $DB_INSTANCE `
        --database-version=POSTGRES_15 `
        --tier=$DB_TIER `
        --region=$REGION `
        --storage-auto-increase `
        --availability-type=zonal
    Write-Host "  Cloud SQL instance created." -ForegroundColor Green
} else {
    Write-Host "  Cloud SQL instance already exists, skipping." -ForegroundColor Green
}

# Generate and set DB password
$bytes = New-Object byte[] 24
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$DB_PASSWORD = [Convert]::ToBase64String($bytes)

gcloud sql users set-password $DB_USER --instance=$DB_INSTANCE --password=$DB_PASSWORD

# Create database
$existingDb = gcloud sql databases list --instance=$DB_INSTANCE --filter="name=$DB_NAME" --format="value(name)" 2>$null
if (-not $existingDb) {
    gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE
}

$CONNECTION_NAME = gcloud sql instances describe $DB_INSTANCE --format="value(connectionName)"
Write-Host "  Connection: $CONNECTION_NAME" -ForegroundColor Green

# ── 3. Store secrets ────────────────────────────────────────
Write-Host "`n-> Storing secrets in Secret Manager..." -ForegroundColor Yellow

$bytes2 = New-Object byte[] 50
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes2)
$DJANGO_SECRET_KEY = [Convert]::ToBase64String($bytes2)

function Set-GcpSecret($name, $value) {
    $exists = gcloud secrets list --filter="name:$name" --format="value(name)" 2>$null
    if ($exists) {
        $value | gcloud secrets versions add $name --data-file=-
    } else {
        $value | gcloud secrets create $name --data-file=- --replication-policy=automatic
    }
}

Set-GcpSecret "django-secret-key" $DJANGO_SECRET_KEY
Set-GcpSecret "db-password" $DB_PASSWORD

# ── 4. Build & push Docker image ────────────────────────────
Write-Host "`n-> Building Docker image with Cloud Build..." -ForegroundColor Yellow
$IMAGE_URL = "$REGION-docker.pkg.dev/$PROJECT_ID/$SERVICE_NAME/${SERVICE_NAME}:latest"

$existingRepo = gcloud artifacts repositories list --location=$REGION --filter="name:$SERVICE_NAME" --format="value(name)" 2>$null
if (-not $existingRepo) {
    gcloud artifacts repositories create $SERVICE_NAME --repository-format=docker --location=$REGION
}

gcloud builds submit --tag $IMAGE_URL .

# ── 5. Deploy to Cloud Run ──────────────────────────────────
Write-Host "`n-> Deploying to Cloud Run..." -ForegroundColor Yellow
$SERVICE_URL = gcloud run deploy $SERVICE_NAME `
    --image $IMAGE_URL `
    --region $REGION `
    --platform managed `
    --allow-unauthenticated `
    --add-cloudsql-instances $CONNECTION_NAME `
    --port 8080 `
    --memory 512Mi `
    --min-instances 0 `
    --max-instances 4 `
    --set-env-vars "DEBUG=False" `
    --set-env-vars "DB_NAME=$DB_NAME" `
    --set-env-vars "DB_USER=$DB_USER" `
    --set-env-vars "DB_HOST=/cloudsql/$CONNECTION_NAME" `
    --set-env-vars "DB_PORT=5432" `
    --set-secrets "SECRET_KEY=django-secret-key:latest,DB_PASSWORD=db-password:latest" `
    --format "value(status.url)"

$SERVICE_URL = $SERVICE_URL.Trim()

# Update CORS/CSRF with deployed URL
Write-Host "`n-> Updating service with origin settings..." -ForegroundColor Yellow
gcloud run services update $SERVICE_NAME `
    --region $REGION `
    --update-env-vars "ALLOWED_HOSTS=.run.app,localhost,127.0.0.1" `
    --update-env-vars "CORS_ALLOWED_ORIGIN=$SERVICE_URL" `
    --update-env-vars "CSRF_TRUSTED_ORIGIN=$SERVICE_URL"

# ── 6. Run migrations ───────────────────────────────────────
Write-Host "`n-> Running database migrations..." -ForegroundColor Yellow
gcloud run jobs create migrate-db `
    --image $IMAGE_URL `
    --region $REGION `
    --set-cloudsql-instances $CONNECTION_NAME `
    --set-env-vars "DEBUG=False,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_HOST=/cloudsql/$CONNECTION_NAME,DB_PORT=5432" `
    --set-secrets "SECRET_KEY=django-secret-key:latest,DB_PASSWORD=db-password:latest" `
    --command "python" `
    --args "manage.py,migrate,--noinput" 2>$null

gcloud run jobs execute migrate-db --region $REGION --wait

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  App URL: $SERVICE_URL"
Write-Host "  Cloud SQL: $CONNECTION_NAME"
Write-Host "  Database: $DB_NAME"
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  To create a superuser, run:" -ForegroundColor Cyan
Write-Host "  gcloud run jobs create create-superuser `` "
Write-Host "    --image $IMAGE_URL `` "
Write-Host "    --region $REGION `` "
Write-Host "    --set-cloudsql-instances $CONNECTION_NAME `` "
Write-Host "    --set-env-vars `"DEBUG=False,DB_NAME=$DB_NAME,DB_USER=$DB_USER,DB_HOST=/cloudsql/$CONNECTION_NAME,DB_PORT=5432,DJANGO_SUPERUSER_USERNAME=admin,DJANGO_SUPERUSER_EMAIL=admin@example.com,DJANGO_SUPERUSER_PASSWORD=changeme`" `` "
Write-Host "    --set-secrets `"SECRET_KEY=django-secret-key:latest,DB_PASSWORD=db-password:latest`" `` "
Write-Host "    --command python --args manage.py,createsuperuser,--noinput"
Write-Host ""
Write-Host "  Then: gcloud run jobs execute create-superuser --region $REGION --wait"
