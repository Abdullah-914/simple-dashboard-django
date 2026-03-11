import { useState, useEffect } from "react";
import api from "../api";

export default function TaskModal({
  task,
  teams,
  defaultTeam,
  onClose,
  onSaved,
}) {
  const isEdit = !!task;
  const [form, setForm] = useState({
    title: "",
    description: "",
    team: defaultTeam || (teams.length > 0 ? teams[0].id : ""),
    assigned_to_id: "",
    priority: "medium",
    status: "todo",
    due_date: "",
  });
  const [members, setMembers] = useState([]);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (task) {
      setForm({
        title: task.title,
        description: task.description || "",
        team: task.team,
        assigned_to_id: task.assigned_to?.id || "",
        priority: task.priority,
        status: task.status,
        due_date: task.due_date || "",
      });
    }
  }, [task]);

  useEffect(() => {
    if (form.team) {
      api
        .get(`/teams/${form.team}/members/`)
        .then((res) => setMembers(res.data))
        .catch(() => setMembers([]));
    }
  }, [form.team]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrors({});
    setLoading(true);

    const payload = { ...form };
    if (!payload.assigned_to_id) payload.assigned_to_id = null;
    if (!payload.due_date) delete payload.due_date;

    try {
      if (isEdit) {
        await api.patch(`/tasks/${task.id}/`, payload);
      } else {
        await api.post("/tasks/", payload);
      }
      onSaved();
    } catch (err) {
      const data = err.response?.data || {};
      if (typeof data === "object") setErrors(data);
      else setErrors({ detail: "Failed to save task." });
    } finally {
      setLoading(false);
    }
  };

  const fieldError = (field) =>
    errors[field] ? (
      <p className="text-red-500 text-xs mt-1">
        {Array.isArray(errors[field]) ? errors[field][0] : errors[field]}
      </p>
    ) : null;

  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-lg font-bold text-gray-800">
            {isEdit ? "Edit Task" : "New Task"}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {errors.detail && (
            <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
              {errors.detail}
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">
              Title
            </label>
            <input
              type="text"
              required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none"
              value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })}
            />
            {fieldError("title")}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-600 mb-1">
              Description
            </label>
            <textarea
              rows={3}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none resize-none"
              value={form.description}
              onChange={(e) =>
                setForm({ ...form, description: e.target.value })
              }
            />
            {fieldError("description")}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Team
              </label>
              <select
                required
                className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                value={form.team}
                onChange={(e) =>
                  setForm({
                    ...form,
                    team: Number(e.target.value),
                    assigned_to_id: "",
                  })
                }
              >
                {teams.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name}
                  </option>
                ))}
              </select>
              {fieldError("team")}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Assign To
              </label>
              <select
                className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                value={form.assigned_to_id}
                onChange={(e) =>
                  setForm({
                    ...form,
                    assigned_to_id: e.target.value
                      ? Number(e.target.value)
                      : "",
                  })
                }
              >
                <option value="">Unassigned</option>
                {members.map((m) => (
                  <option key={m.id} value={m.id}>
                    {m.first_name || m.username}
                  </option>
                ))}
              </select>
              {fieldError("assigned_to_id")}
            </div>
          </div>

          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Priority
              </label>
              <select
                className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                value={form.priority}
                onChange={(e) =>
                  setForm({ ...form, priority: e.target.value })
                }
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Status
              </label>
              <select
                className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                value={form.status}
                onChange={(e) => setForm({ ...form, status: e.target.value })}
              >
                <option value="todo">To Do</option>
                <option value="in_progress">In Progress</option>
                <option value="done">Done</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-600 mb-1">
                Due Date
              </label>
              <input
                type="date"
                className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                value={form.due_date}
                onChange={(e) =>
                  setForm({ ...form, due_date: e.target.value })
                }
              />
            </div>
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-50 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-4 py-2 bg-indigo-600 text-white rounded-lg text-sm font-semibold hover:bg-indigo-700 transition disabled:opacity-50"
            >
              {loading
                ? "Saving…"
                : isEdit
                ? "Update Task"
                : "Create Task"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
