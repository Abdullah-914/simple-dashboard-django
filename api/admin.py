from django.contrib import admin

from .models import Task, Team, TeamMembership


class TeamMembershipInline(admin.TabularInline):
    model = TeamMembership
    extra = 0


@admin.register(Team)
class TeamAdmin(admin.ModelAdmin):
    list_display = ["name", "created_by", "created_at"]
    inlines = [TeamMembershipInline]


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ["title", "team", "assigned_to", "status", "priority", "due_date"]
    list_filter = ["status", "priority", "team"]
