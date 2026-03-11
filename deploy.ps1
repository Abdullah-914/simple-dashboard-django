# ============================================================
# deploy.ps1 — Deploy to Google Cloud (Cloud Run + Firebase)
#
# Architecture:
#   React Frontend  → Firebase Hosting (free)
#   Django Backend   → Cloud Run (container)
#   PostgreSQL       → Inside the container (no Cloud SQL)
#
# Prerequisites:
#   1. Google Cloud SDK (gcloud) — https://cloud.google.com/sdk/docs/install
#   2. Node.js & npm
#   3. Authenticated: gcloud auth login
#
# Usage:
#   $env:GCP_PROJECT_ID = "your-project-id"
#   .\deploy.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$PROJECT_ID = $env:GCP_PROJECT_ID
if (-not $PROJECT_ID) { throw "Set GCP_PROJECT_ID first: `$env:GCP_PROJECT_ID = 'your-project-id'" }
$REGION       = if ($env:GCP_REGION) { $env:GCP_REGION } else { "us-central1" }
$SERVICE_NAME = "team-task-manager"

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "  Deploying to GCP: $PROJECT_ID ($REGION)"
Write-Host "  Backend:  Cloud Run ($SERVICE_NAME)"
Write-Host "  Frontend: Firebase Hosting"
Write-Host "  Database: PostgreSQL (in-container)"
Write-Host "=================================================" -ForegroundColor Cyan

# ── 1. Set project & enable APIs ────────────────────────────
Write-Host "`n[1/6] Setting project and enabling APIs..." -ForegroundColor Yellow
gcloud config set project $PROJECT_ID
gcloud services enable `
    run.googleapis.com `
    cloudbuild.googleapis.com `
    artifactregistry.googleapis.com `
    firebasehosting.googleapis.com

# ── 2. Create Artifact Registry repo ────────────────────────
Write-Host "`n[2/6] Setting up Artifact Registry..." -ForegroundColor Yellow
$existingRepo = gcloud artifacts repositories list --location=$REGION --filter="name:$SERVICE_NAME" --format="value(name)" 2>$null
if (-not $existingRepo) {
    gcloud artifacts repositories create $SERVICE_NAME --repository-format=docker --location=$REGION
}

# ── 3. Build & deploy to Cloud Run ──────────────────────────
Write-Host "`n[3/6] Building container and deploying to Cloud Run..." -ForegroundColor Yellow
$IMAGE_URL = "$REGION-docker.pkg.dev/$PROJECT_ID/$SERVICE_NAME/${SERVICE_NAME}:latest"

# Generate a random secret key for production
$bytes = New-Object byte[] 50
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$SECRET_KEY = [Convert]::ToBase64String($bytes)

gcloud builds submit --tag $IMAGE_URL .

$SERVICE_URL = gcloud run deploy $SERVICE_NAME `
    --image $IMAGE_URL `
    --region $REGION `
    --platform managed `
    --allow-unauthenticated `
    --port 8080 `
    --memory 512Mi `
    --min-instances 0 `
    --max-instances 4 `
    --set-env-vars "DEBUG=False" `
    --set-env-vars "SECRET_KEY=$SECRET_KEY" `
    --set-env-vars "ALLOWED_HOSTS=.run.app,.web.app,.firebaseapp.com,localhost" `
    --set-env-vars "DJANGO_SUPERUSER_USERNAME=admin" `
    --set-env-vars "DJANGO_SUPERUSER_EMAIL=admin@example.com" `
    --set-env-vars "DJANGO_SUPERUSER_PASSWORD=admin123" `
    --format "value(status.url)"

$SERVICE_URL = $SERVICE_URL.Trim()
Write-Host "  Cloud Run URL: $SERVICE_URL" -ForegroundColor Green

# Update CORS/CSRF with the Firebase Hosting URL
$FIREBASE_URL = "https://$PROJECT_ID.web.app"
gcloud run services update $SERVICE_NAME `
    --region $REGION `
    --update-env-vars "CORS_ALLOWED_ORIGIN=$FIREBASE_URL" `
    --update-env-vars "CSRF_TRUSTED_ORIGIN=$FIREBASE_URL"

# ── 4. Build React frontend ─────────────────────────────────
Write-Host "`n[4/6] Building React frontend..." -ForegroundColor Yellow
Push-Location frontend
npm ci
npm run build
Pop-Location

# ── 5. Add Firebase to project ──────────────────────────────
Write-Host "`n[5/6] Setting up Firebase..." -ForegroundColor Yellow
Write-Host "  If prompted, log in with the same Google account used for gcloud."

# Install firebase-tools locally if not present
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing Firebase CLI..."
    npm install -g firebase-tools
}

firebase login --no-localhost 2>$null
firebase projects:addfirebase $PROJECT_ID 2>$null

# ── 6. Deploy frontend to Firebase Hosting ──────────────────
Write-Host "`n[6/6] Deploying frontend to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting --project $PROJECT_ID

$FIREBASE_URL = "https://$PROJECT_ID.web.app"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Green
Write-Host "  Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend: $FIREBASE_URL"
Write-Host "  Backend:  $SERVICE_URL"
Write-Host "  Database: PostgreSQL (inside Cloud Run container)"
Write-Host ""
Write-Host "  Default admin account:"
Write-Host "    Username: admin"
Write-Host "    Password: admin123"
Write-Host "    Admin panel: $FIREBASE_URL/admin/"
Write-Host "=================================================" -ForegroundColor Green
