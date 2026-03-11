from django.urls import path

from . import views

app_name = "api"

urlpatterns = [
    # Auth
    path("auth/csrf/", views.CSRFTokenView.as_view(), name="csrf"),
    path("auth/register/", views.RegisterView.as_view(), name="register"),
    path("auth/login/", views.LoginView.as_view(), name="login"),
    path("auth/logout/", views.LogoutView.as_view(), name="logout"),
    path("auth/me/", views.MeView.as_view(), name="me"),
    # Teams
    path("teams/", views.TeamListCreateView.as_view(), name="team-list"),
    path("teams/<int:pk>/", views.TeamDetailView.as_view(), name="team-detail"),
    path("teams/<int:pk>/members/", views.TeamMembersView.as_view(), name="team-members"),
    path("teams/<int:pk>/add-member/", views.TeamAddMemberView.as_view(), name="team-add-member"),
    path("teams/<int:pk>/remove-member/<int:user_id>/", views.TeamRemoveMemberView.as_view(), name="team-remove-member"),
    # Tasks
    path("tasks/", views.TaskListCreateView.as_view(), name="task-list"),
    path("tasks/<int:pk>/", views.TaskDetailView.as_view(), name="task-detail"),
    # Bonus
    path("tasks/reminders/", views.DueTasksReminderView.as_view(), name="task-reminders"),
    path("teams/<int:pk>/invite/", views.InviteMemberView.as_view(), name="team-invite"),
]
