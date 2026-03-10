import { useEffect, useState, useCallback } from "react";
import { useAuth } from "../contexts/AuthContext";
import api from "../api";
import TeamSidebar from "../components/TeamSidebar";
import TaskList from "../components/TaskList";
import TaskModal from "../components/TaskModal";
import Reminders from "../components/Reminders";

export default function DashboardPage() {
  const { user, logout } = useAuth();
  const [teams, setTeams] = useState([]);
  const [selectedTeam, setSelectedTeam] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [filters, setFilters] = useState({
    search: "",
    assignee: "",
    status: "",
    priority: "",
  });
  const [taskModal, setTaskModal] = useState({ open: false, task: null });
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const fetchTeams = useCallback(async () => {
    const res = await api.get("/teams/");
    setTeams(res.data);
  }, []);

  const fetchTasks = useCallback(async () => {
    const params = {};
    if (selectedTeam) params.team = selectedTeam;
    if (filters.assignee) params.assignee = filters.assignee;
    if (filters.status) params.status = filters.status;
    if (filters.priority) params.priority = filters.priority;
    if (filters.search) params.search = filters.search;
    const res = await api.get("/tasks/", { params });
    setTasks(res.data);
  }, [selectedTeam, filters]);

  useEffect(() => {
    fetchTeams();
  }, [fetchTeams]);

  useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  const handleTaskSaved = () => {
    setTaskModal({ open: false, task: null });
    fetchTasks();
  };

  const handleDeleteTask = async (id) => {
    await api.delete(`/tasks/${id}/`);
    fetchTasks();
  };

  const currentTeam = teams.find((t) => t.id === selectedTeam);

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Top Nav */}
      <header className="bg-indigo-700 text-white shadow-md">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="lg:hidden p-1 rounded hover:bg-indigo-600"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <h1 className="text-xl font-bold">Team Task Manager</h1>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-sm hidden sm:inline">
              {user?.first_name || user?.username}
            </span>
            <button
              onClick={logout}
              className="bg-indigo-600 hover:bg-indigo-500 px-3 py-1.5 rounded-lg text-sm font-medium transition"
            >
              Logout
            </button>
          </div>
        </div>
      </header>

      <div className="flex flex-1 overflow-hidden">
        {/* Sidebar */}
        <aside
          className={`${
            sidebarOpen ? "translate-x-0" : "-translate-x-full"
          } lg:translate-x-0 fixed lg:static inset-y-0 left-0 z-30 w-72 bg-white border-r border-gray-200 shadow-lg lg:shadow-none transition-transform duration-200 pt-16 lg:pt-0`}
        >
          <TeamSidebar
            teams={teams}
            selectedTeam={selectedTeam}
            onSelectTeam={(id) => {
              setSelectedTeam(id);
              setSidebarOpen(false);
            }}
            onTeamsChanged={fetchTeams}
          />
        </aside>

        {/* Overlay for mobile sidebar */}
        {sidebarOpen && (
          <div
            className="fixed inset-0 bg-black/30 z-20 lg:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}

        {/* Main Content */}
        <main className="flex-1 overflow-auto p-4 md:p-6">
          <Reminders />

          {/* Filters */}
          <div className="bg-white rounded-xl shadow-sm p-4 mb-6">
            <div className="flex flex-col sm:flex-row gap-3 items-start sm:items-center justify-between">
              <div className="flex flex-wrap gap-2 flex-1">
                <input
                  type="text"
                  placeholder="Search tasks…"
                  className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none w-full sm:w-48"
                  value={filters.search}
                  onChange={(e) =>
                    setFilters({ ...filters, search: e.target.value })
                  }
                />
                <select
                  className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                  value={filters.status}
                  onChange={(e) =>
                    setFilters({ ...filters, status: e.target.value })
                  }
                >
                  <option value="">All Status</option>
                  <option value="todo">To Do</option>
                  <option value="in_progress">In Progress</option>
                  <option value="done">Done</option>
                </select>
                <select
                  className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                  value={filters.priority}
                  onChange={(e) =>
                    setFilters({ ...filters, priority: e.target.value })
                  }
                >
                  <option value="">All Priority</option>
                  <option value="low">Low</option>
                  <option value="medium">Medium</option>
                  <option value="high">High</option>
                </select>
                {currentTeam && (
                  <select
                    className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                    value={filters.assignee}
                    onChange={(e) =>
                      setFilters({ ...filters, assignee: e.target.value })
                    }
                  >
                    <option value="">All Assignees</option>
                    {currentTeam.memberships?.map((m) => (
                      <option key={m.user.id} value={m.user.id}>
                        {m.user.first_name || m.user.username}
                      </option>
                    ))}
                  </select>
                )}
              </div>
              <button
                onClick={() => setTaskModal({ open: true, task: null })}
                disabled={teams.length === 0}
                className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition disabled:opacity-50 whitespace-nowrap"
              >
                + New Task
              </button>
            </div>
          </div>

          {/* Task List */}
          <TaskList
            tasks={tasks}
            onEdit={(task) => setTaskModal({ open: true, task })}
            onDelete={handleDeleteTask}
          />
        </main>
      </div>

      {/* Task Modal */}
      {taskModal.open && (
        <TaskModal
          task={taskModal.task}
          teams={teams}
          defaultTeam={selectedTeam}
          onClose={() => setTaskModal({ open: false, task: null })}
          onSaved={handleTaskSaved}
        />
      )}
    </div>
  );
}
