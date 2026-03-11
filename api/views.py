from django.contrib.auth import authenticate, get_user_model, login, logout
from django.db.models import Q
from django.middleware.csrf import get_token
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Task, Team, TeamMembership
from .serializers import (
    AddMemberSerializer,
    LoginSerializer,
    RegisterSerializer,
    TaskSerializer,
    TeamCreateSerializer,
    TeamSerializer,
    UserSerializer,
)

User = get_user_model()


# ──────────────────── Auth Views ────────────────────


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        login(request, user)
        return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = authenticate(
            request,
            username=serializer.validated_data["username"],
            password=serializer.validated_data["password"],
        )
        if user is None:
            return Response(
                {"detail": "Invalid credentials."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        login(request, user)
        return Response(UserSerializer(user).data)


class LogoutView(APIView):
    def post(self, request):
        logout(request)
        return Response({"detail": "Logged out."})


class MeView(APIView):
    def get(self, request):
        return Response(UserSerializer(request.user).data)


class CSRFTokenView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({"csrfToken": get_token(request)})


# ──────────────────── Team Views ────────────────────


class TeamListCreateView(generics.ListCreateAPIView):
    def get_serializer_class(self):
        if self.request.method == "POST":
            return TeamCreateSerializer
        return TeamSerializer

    def get_queryset(self):
        return Team.objects.filter(memberships__user=self.request.user).distinct()

    def perform_create(self, serializer):
        team = serializer.save(created_by=self.request.user)
        TeamMembership.objects.create(user=self.request.user, team=team, role="admin")


class TeamDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TeamSerializer

    def get_queryset(self):
        return Team.objects.filter(memberships__user=self.request.user)

    def perform_destroy(self, instance):
        if instance.created_by != self.request.user:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only the team creator can delete this team.")
        instance.delete()


class TeamAddMemberView(APIView):
    def post(self, request, pk):
        team = generics.get_object_or_404(
            Team.objects.filter(memberships__user=request.user), pk=pk
        )
        membership = team.memberships.filter(user=request.user).first()
        if not membership or membership.role != "admin":
            return Response(
                {"detail": "Only team admins can add members."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = AddMemberSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            new_user = User.objects.get(username=serializer.validated_data["username"])
        except User.DoesNotExist:
            return Response(
                {"detail": "User not found."}, status=status.HTTP_404_NOT_FOUND
            )
        if team.memberships.filter(user=new_user).exists():
            return Response(
                {"detail": "User is already a member."}, status=status.HTTP_400_BAD_REQUEST
            )
        TeamMembership.objects.create(
            user=new_user, team=team, role=serializer.validated_data.get("role", "member")
        )
        return Response(
            TeamSerializer(team).data, status=status.HTTP_201_CREATED
        )


class TeamRemoveMemberView(APIView):
    def delete(self, request, pk, user_id):
        team = generics.get_object_or_404(
            Team.objects.filter(memberships__user=request.user), pk=pk
        )
        membership = team.memberships.filter(user=request.user).first()
        if not membership or membership.role != "admin":
            return Response(
                {"detail": "Only team admins can remove members."},
                status=status.HTTP_403_FORBIDDEN,
            )
        target = team.memberships.filter(user_id=user_id).first()
        if not target:
            return Response(
                {"detail": "User is not a member."}, status=status.HTTP_404_NOT_FOUND
            )
        if target.user == team.created_by:
            return Response(
                {"detail": "Cannot remove the team creator."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        target.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class TeamMembersView(APIView):
    def get(self, request, pk):
        team = generics.get_object_or_404(
            Team.objects.filter(memberships__user=request.user), pk=pk
        )
        members = team.memberships.select_related("user").all()
        data = [
            {
                "id": m.user.id,
                "username": m.user.username,
                "email": m.user.email,
                "first_name": m.user.first_name,
                "last_name": m.user.last_name,
                "role": m.role,
            }
            for m in members
        ]
        return Response(data)


# ──────────────────── Task Views ────────────────────


class TaskListCreateView(generics.ListCreateAPIView):
    serializer_class = TaskSerializer

    def get_queryset(self):
        user_teams = Team.objects.filter(memberships__user=self.request.user)
        qs = Task.objects.filter(team__in=user_teams).select_related(
            "assigned_to", "created_by", "team"
        )

        team_id = self.request.query_params.get("team")
        if team_id:
            qs = qs.filter(team_id=team_id)

        assignee = self.request.query_params.get("assignee")
        if assignee:
            qs = qs.filter(assigned_to_id=assignee)

        status_filter = self.request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter)

        priority = self.request.query_params.get("priority")
        if priority:
            qs = qs.filter(priority=priority)

        search = self.request.query_params.get("search")
        if search:
            qs = qs.filter(Q(title__icontains=search) | Q(description__icontains=search))

        return qs

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class TaskDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = TaskSerializer

    def get_queryset(self):
        user_teams = Team.objects.filter(memberships__user=self.request.user)
        return Task.objects.filter(team__in=user_teams).select_related(
            "assigned_to", "created_by", "team"
        )
