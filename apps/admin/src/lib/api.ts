import axios, { type AxiosError, type InternalAxiosRequestConfig } from "axios";
import { API_BASE_URL } from "./config.ts";
import { getAccessToken, getRefreshToken, setTokens, clearTokens } from "./authStorage.ts";

export const SESSION_EXPIRED_EVENT = "sanchalan-admin:session-expired";

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000,
});

api.interceptors.request.use((config) => {
  const isAuthEndpoint = config.url?.startsWith("/admin/auth/") || config.url?.startsWith("/auth/");
  if (!isAuthEndpoint) {
    const accessToken = getAccessToken();
    if (accessToken) {
      config.headers.set("Authorization", `Bearer ${accessToken}`);
    }
  }
  return config;
});

// Coalesce concurrent 401s (e.g. two requests fire at once) into one refresh call.
let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return null;
  try {
    // Plain axios call (not `api`) — avoids recursing through these same interceptors.
    const { data } = await axios.post(`${API_BASE_URL}/auth/refresh`, { refreshToken });
    setTokens({ accessToken: data.accessToken, refreshToken });
    return data.accessToken as string;
  } catch {
    return null;
  }
}

type RetryableConfig = InternalAxiosRequestConfig & { _retry?: boolean };

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const original = error.config as RetryableConfig | undefined;
    const isAuthEndpoint =
      original?.url?.startsWith("/admin/auth/") || original?.url?.startsWith("/auth/");

    if (error.response?.status === 401 && original && !original._retry && !isAuthEndpoint) {
      original._retry = true;

      if (!refreshPromise) {
        refreshPromise = refreshAccessToken().finally(() => {
          refreshPromise = null;
        });
      }
      const newAccessToken = await refreshPromise;

      if (newAccessToken) {
        original.headers.set("Authorization", `Bearer ${newAccessToken}`);
        return api(original);
      }

      // Refresh itself failed — the session is dead. Clear local tokens and
      // let AuthProvider (listening for this event) flip the app to "unauthed".
      clearTokens();
      window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
    }

    return Promise.reject(error);
  }
);
