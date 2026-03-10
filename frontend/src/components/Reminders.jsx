import { useEffect, useState } from "react";
import api from "../api";

export default function Reminders() {
  const [tasks, setTasks] = useState([]);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    api
      .get("/tasks/reminders/")
      .then((res) => setTasks(res.data))
      .catch(() => {});
  }, []);

  if (dismissed || tasks.length === 0) return null;

  return (
    <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6">
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-2">
          <svg className="w-5 h-5 text-amber-500 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 className="font-semibold text-amber-800 text-sm">
            Due / Overdue Tasks ({tasks.length})
          </h3>
        </div>
        <button
          onClick={() => setDismissed(true)}
          className="text-amber-400 hover:text-amber-600"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <ul className="mt-2 space-y-1">
        {tasks.slice(0, 5).map((t) => (
          <li key={t.id} className="text-sm text-amber-700">
            <span className="font-medium">{t.title}</span>
            <span className="text-amber-500 ml-2">
              Due {new Date(t.due_date).toLocaleDateString()}
            </span>
          </li>
        ))}
        {tasks.length > 5 && (
          <li className="text-xs text-amber-500">
            …and {tasks.length - 5} more
          </li>
        )}
      </ul>
    </div>
  );
}
