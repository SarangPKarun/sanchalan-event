const rawApiUrl = import.meta.env.VITE_API_URL ?? "http://localhost:3000";
// Tolerate a trailing slash in the env var so `${API_BASE_URL}/path` never yields "//path".
export const API_BASE_URL = rawApiUrl.replace(/\/+$/, "");
