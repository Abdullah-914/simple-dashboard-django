from django.db import models


class Project(models.Model):
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    status = models.CharField(
        max_length=20,
        choices=[
            ("active", "Active"),
            ("completed", "Completed"),
            ("on_hold", "On Hold"),
        ],
        default="active",
    )
    progress = models.IntegerField(default=0)  # 0-100
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class Task(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="tasks")
    title = models.CharField(max_length=200)
    completed = models.BooleanField(default=False)
    priority = models.CharField(
        max_length=10,
        choices=[("low", "Low"), ("medium", "Medium"), ("high", "High")],
        default="medium",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class Activity(models.Model):
    description = models.CharField(max_length=300)
    icon = models.CharField(max_length=50, default="bi-activity")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-timestamp"]
        verbose_name_plural = "activities"

    def __str__(self):
        return self.description
