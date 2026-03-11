import { useState } from "react";
import api from "../api";

export default function TeamSidebar({
  teams,
  selectedTeam,
  onSelectTeam,
  onTeamsChanged,
}) {
  const [showCreate, setShowCreate] = useState(false);
  const [newTeam, setNewTeam] = useState({ name: "", description: "" });
  const [addMember, setAddMember] = useState({ teamId: null, username: "" });
  const [error, setError] = useState("");

  const handleCreateTeam = async (e) => {
    e.preventDefault();
    if (!newTeam.name.trim()) return;
    try {
      await api.post("/teams/", newTeam);
      setNewTeam({ name: "", description: "" });
      setShowCreate(false);
      onTeamsChanged();
    } catch (err) {
      setError(err.response?.data?.detail || "Failed to create team.");
    }
  };

  const handleAddMember = async (e) => {
    e.preventDefault();
    if (!addMember.username.trim()) return;
    setError("");
    try {
      await api.post(`/teams/${addMember.teamId}/add-member/`, {
        username: addMember.username,
      });
      setAddMember({ teamId: null, username: "" });
      onTeamsChanged();
    } catch (err) {
      setError(
        err.response?.data?.detail || "Failed to add member."
      );
    }
  };

  const handleDeleteTeam = async (id) => {
    if (!confirm("Delete this team and all its tasks?")) return;
    try {
      await api.delete(`/teams/${id}/`);
      if (selectedTeam === id) onSelectTeam(null);
      onTeamsChanged();
    } catch (err) {
      setError(err.response?.data?.detail || "Failed to delete team.");
    }
  };

  return (
    <div className="h-full flex flex-col">
      <div className="p-4 border-b border-gray-200">
        <div className="flex items-center justify-between mb-2">
          <h2 className="text-lg font-bold text-gray-800">Teams</h2>
          <button
            onClick={() => setShowCreate(!showCreate)}
            className="text-indigo-600 hover:text-indigo-800 text-sm font-medium"
          >
            {showCreate ? "Cancel" : "+ New"}
          </button>
        </div>

        {showCreate && (
          <form onSubmit={handleCreateTeam} className="space-y-2 mt-2">
            <input
              type="text"
              placeholder="Team name"
              required
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none"
              value={newTeam.name}
              onChange={(e) =>
                setNewTeam({ ...newTeam, name: e.target.value })
              }
            />
            <input
              type="text"
              placeholder="Description (optional)"
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none"
              value={newTeam.description}
              onChange={(e) =>
                setNewTeam({ ...newTeam, description: e.target.value })
              }
            />
            <button
              type="submit"
              className="w-full bg-indigo-600 text-white py-1.5 rounded-lg text-sm font-semibold hover:bg-indigo-700 transition"
            >
              Create Team
            </button>
          </form>
        )}
      </div>

      {error && (
        <div className="mx-4 mt-2 bg-red-50 text-red-600 p-2 rounded text-xs">
          {error}
        </div>
      )}

      <div className="flex-1 overflow-auto">
        <button
          onClick={() => onSelectTeam(null)}
          className={`w-full text-left px-4 py-3 text-sm font-medium border-b border-gray-100 transition ${
            selectedTeam === null
              ? "bg-indigo-50 text-indigo-700"
              : "text-gray-600 hover:bg-gray-50"
          }`}
        >
          All Teams
        </button>
        {teams.map((team) => (
          <div
            key={team.id}
            className={`border-b border-gray-100 ${
              selectedTeam === team.id ? "bg-indigo-50" : ""
            }`}
          >
            <div className="flex items-center">
              <button
                onClick={() => onSelectTeam(team.id)}
                className={`flex-1 text-left px-4 py-3 text-sm font-medium transition ${
                  selectedTeam === team.id
                    ? "text-indigo-700"
                    : "text-gray-600 hover:bg-gray-50"
                }`}
              >
                <div>{team.name}</div>
                <div className="text-xs text-gray-400">
                  {team.member_count} member{team.member_count !== 1 ? "s" : ""}
                </div>
              </button>

              <div className="flex gap-1 pr-2">
                <button
                  onClick={() =>
                    setAddMember(
                      addMember.teamId === team.id
                        ? { teamId: null, username: "" }
                        : { teamId: team.id, username: "" }
                    )
                  }
                  className="text-gray-400 hover:text-indigo-600 p-1"
                  title="Add member"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                  </svg>
                </button>
                <button
                  onClick={() => handleDeleteTeam(team.id)}
                  className="text-gray-400 hover:text-red-600 p-1"
                  title="Delete team"
                >
                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>

            {addMember.teamId === team.id && (
              <form
                onSubmit={handleAddMember}
                className="px-4 pb-3 flex gap-2"
              >
                <input
                  type="text"
                  placeholder="Username"
                  required
                  className="flex-1 border border-gray-300 rounded-lg px-2 py-1 text-sm focus:ring-2 focus:ring-indigo-400 focus:outline-none"
                  value={addMember.username}
                  onChange={(e) =>
                    setAddMember({ ...addMember, username: e.target.value })
                  }
                />
                <button
                  type="submit"
                  className="bg-indigo-600 text-white px-3 py-1 rounded-lg text-sm hover:bg-indigo-700"
                >
                  Add
                </button>
              </form>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
