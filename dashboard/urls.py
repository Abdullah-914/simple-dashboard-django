from django.urls import path
from . import views

app_name = "dashboard"

urlpatterns = [
    path("", views.index, name="index"),
    path("project/<int:pk>/", views.project_detail, name="project_detail"),
    path("project/add/", views.add_project, name="add_project"),
    path("project/<int:project_pk>/add-task/", views.add_task, name="add_task"),
    path("task/<int:task_pk>/toggle/", views.toggle_task, name="toggle_task"),
]
