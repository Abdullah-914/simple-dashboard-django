# Team Task Manager

A full-stack team task management application built with **Django REST Framework** (backend) and **React + Vite + Tailwind CSS** (frontend).

## Features

- User registration & login (session-based auth)
- Create and manage teams
- Invite members to teams
- Create, assign, and track tasks with priorities and due dates
- Filter tasks by status, priority, and assignee
- Due-date reminders
- Django admin panel for data management

## Tech Stack

| Layer    | Technology                              |
| -------- | --------------------------------------- |
| Backend  | Django 6.0, Django REST Framework 3.16  |
| Frontend | React 19, Vite 7, Tailwind CSS 4       |
| Database | PostgreSQL (production) / SQLite (dev)  |
| Auth     | Session-based with BCrypt password hashing |

## Prerequisites

- **Python 3.12+**
- **Node.js 18+** and **npm**
- **Git**

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/Abdullah-914/simple-dashboard-django.git
cd simple-dashboard-django
```

### 2. Set up the backend

Create and activate a virtual environment:

```bash
# Windows
python -m venv env
env\Scripts\activate

# macOS / Linux
python3 -m venv env
source env/bin/activate
```

Install Python dependencies:

```bash
pip install -r requirements.txt
```

Run database migrations:

```bash
python manage.py migrate
```

Create a superuser (for the admin panel):

```bash
python manage.py createsuperuser
```

### 3. Set up the frontend

```bash
cd frontend
npm install
cd ..
```

### 4. Run the development servers

You need **two terminals** — one for the backend and one for the frontend.

**Terminal 1 — Django backend** (runs on http://127.0.0.1:8000):

```bash
python manage.py runserver
```

**Terminal 2 — React frontend** (runs on http://localhost:5173):

```bash
cd frontend
npm run dev
```

Open **http://localhost:5173** in your browser. The frontend proxies API requests to the Django backend automatically.

## Project Structure

```
├── config/             # Django project settings & URL config
├── api/                # REST API app (models, views, serializers)
├── dashboard/          # Django template-based dashboard app
├── frontend/           # React + Vite frontend
│   └── src/
│       ├── components/ # React components (TaskList, TeamSidebar, etc.)
│       ├── api.js      # Axios instance with CSRF handling
│       └── App.jsx     # Main app with routing
├── build.sh            # Render deployment build script
├── render.yaml         # Render blueprint for one-click deploy
├── requirements.txt    # Python dependencies
└── manage.py           # Django management script
```

## API Endpoints

| Method | Endpoint                        | Description              |
| ------ | ------------------------------- | ------------------------ |
| POST   | `/api/auth/register/`           | Register a new user      |
| POST   | `/api/auth/login/`              | Log in                   |
| POST   | `/api/auth/logout/`             | Log out                  |
| GET    | `/api/auth/user/`               | Get current user info    |
| GET    | `/api/teams/`                   | List your teams          |
| POST   | `/api/teams/`                   | Create a team            |
| GET    | `/api/teams/:id/`               | Team detail              |
| POST   | `/api/teams/:id/invite/`        | Invite a member          |
| GET    | `/api/teams/:id/tasks/`         | List tasks for a team    |
| POST   | `/api/teams/:id/tasks/`         | Create a task            |
| PATCH  | `/api/tasks/:id/`               | Update a task            |
| DELETE | `/api/tasks/:id/`               | Delete a task            |
| GET    | `/api/reminders/`               | Get tasks due soon       |

## Environment Variables (Production)

| Variable                     | Description                          |
| ---------------------------- | ------------------------------------ |
| `SECRET_KEY`                 | Django secret key                    |
| `DEBUG`                      | Set to `False` in production         |
| `DATABASE_URL`               | PostgreSQL connection string         |
| `DJANGO_SUPERUSER_USERNAME`  | Auto-created admin username          |
| `DJANGO_SUPERUSER_EMAIL`     | Auto-created admin email             |
| `DJANGO_SUPERUSER_PASSWORD`  | Auto-created admin password          |

## Deployment (Render)

This project includes a `render.yaml` blueprint for one-click deployment to [Render](https://render.com):

1. Push this repo to your GitHub account
2. Go to [Render Dashboard](https://dashboard.render.com) → **New** → **Blueprint**
3. Connect your repository and deploy

Render will automatically set up a free PostgreSQL database and web service.

## Admin Panel

Access the Django admin at `/admin/` to manage users, teams, and tasks directly.
