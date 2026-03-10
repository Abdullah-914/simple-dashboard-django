const priorityColors = {
  low: "bg-green-100 text-green-700",
  medium: "bg-yellow-100 text-yellow-700",
  high: "bg-red-100 text-red-700",
};

const statusColors = {
  todo: "bg-gray-100 text-gray-700",
  in_progress: "bg-blue-100 text-blue-700",
  done: "bg-green-100 text-green-700",
};

const statusLabels = {
  todo: "To Do",
  in_progress: "In Progress",
  done: "Done",
};

export default function TaskList({ tasks, onEdit, onDelete }) {
  if (tasks.length === 0) {
    return (
      <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">
        <svg className="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
        </svg>
        <p className="text-lg font-medium">No tasks found</p>
        <p className="text-sm">Create a new task or adjust your filters.</p>
      </div>
    );
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {tasks.map((task) => (
        <div
          key={task.id}
          className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 hover:shadow-md transition"
        >
          <div className="flex items-start justify-between mb-2">
            <h3 className="font-semibold text-gray-800 text-sm leading-tight flex-1 mr-2">
              {task.title}
            </h3>
            <div className="flex gap-1 shrink-0">
              <button
                onClick={() => onEdit(task)}
                className="text-gray-400 hover:text-indigo-600 p-1"
                title="Edit"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>
              <button
                onClick={() => onDelete(task.id)}
                className="text-gray-400 hover:text-red-600 p-1"
                title="Delete"
              >
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>

          {task.description && (
            <p className="text-gray-500 text-xs mb-3 line-clamp-2">
              {task.description}
            </p>
          )}

          <div className="flex flex-wrap gap-1.5 mb-3">
            <span
              className={`px-2 py-0.5 rounded-full text-xs font-medium ${priorityColors[task.priority]}`}
            >
              {task.priority}
            </span>
            <span
              className={`px-2 py-0.5 rounded-full text-xs font-medium ${statusColors[task.status]}`}
            >
              {statusLabels[task.status]}
            </span>
          </div>

          <div className="flex items-center justify-between text-xs text-gray-400">
            <span className="bg-gray-50 px-2 py-0.5 rounded">
              {task.team_name}
            </span>
            {task.assigned_to ? (
              <span>
                {task.assigned_to.first_name || task.assigned_to.username}
              </span>
            ) : (
              <span className="italic">Unassigned</span>
            )}
          </div>

          {task.due_date && (
            <div className="mt-2 text-xs text-gray-400">
              Due: {new Date(task.due_date).toLocaleDateString()}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
