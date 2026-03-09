from django.shortcuts import render, get_object_or_404, redirect
from django.db.models import Count, Q
from .models import Project, Task, Activity


def index(request):
    projects = Project.objects.all()
    total_projects = projects.count()
    active_projects = projects.filter(status="active").count()
    completed_projects = projects.filter(status="completed").count()

    total_tasks = Task.objects.count()
    completed_tasks = Task.objects.filter(completed=True).count()
    pending_tasks = total_tasks - completed_tasks
    task_completion_rate = round((completed_tasks / total_tasks * 100) if total_tasks else 0)

    recent_activities = Activity.objects.all()[:10]

    context = {
        "projects": projects,
        "total_projects": total_projects,
        "active_projects": active_projects,
        "completed_projects": completed_projects,
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "pending_tasks": pending_tasks,
        "task_completion_rate": task_completion_rate,
        "recent_activities": recent_activities,
    }
    return render(request, "dashboard/index.html", context)


def project_detail(request, pk):
    project = get_object_or_404(Project, pk=pk)
    tasks = project.tasks.all()
    return render(request, "dashboard/project_detail.html", {"project": project, "tasks": tasks})


def add_project(request):
    if request.method == "POST":
        name = request.POST.get("name", "").strip()
        description = request.POST.get("description", "").strip()
        if name:
            project = Project.objects.create(name=name, description=description)
            Activity.objects.create(
                description=f"New project '{project.name}' created",
                icon="bi-folder-plus",
            )
    return redirect("dashboard:index")


def add_task(request, project_pk):
    project = get_object_or_404(Project, pk=project_pk)
    if request.method == "POST":
        title = request.POST.get("title", "").strip()
        priority = request.POST.get("priority", "medium")
        if title:
            Task.objects.create(project=project, title=title, priority=priority)
            Activity.objects.create(
                description=f"Task '{title}' added to '{project.name}'",
                icon="bi-plus-circle",
            )
    return redirect("dashboard:project_detail", pk=project_pk)


def toggle_task(request, task_pk):
    task = get_object_or_404(Task, pk=task_pk)
    task.completed = not task.completed
    task.save()
    # Update project progress
    project = task.project
    total = project.tasks.count()
    done = project.tasks.filter(completed=True).count()
    project.progress = round((done / total * 100) if total else 0)
    if project.progress == 100:
        project.status = "completed"
    elif project.progress > 0:
        project.status = "active"
    project.save()
    return redirect("dashboard:project_detail", pk=project.pk)
