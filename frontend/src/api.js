import axios from "axios";

const api = axios.create({
  baseURL: "/api",
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

// Fetch CSRF token once and attach to all mutating requests
let csrfToken = null;

async function ensureCsrf() {
  if (!csrfToken) {
    const res = await axios.get("/api/auth/csrf/", { withCredentials: true });
    csrfToken = res.data.csrfToken;
  }
  return csrfToken;
}

api.interceptors.request.use(async (config) => {
  if (["post", "put", "patch", "delete"].includes(config.method)) {
    const token = await ensureCsrf();
    config.headers["X-CSRFToken"] = token;
  }
  return config;
});

export default api;
