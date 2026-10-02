import axios, { type AxiosError, type InternalAxiosRequestConfig } from "axios";
import { router } from "expo-router";
import { API_BASE_URL } from "./config";
import { getAccessToken, getRefreshToken, setTokens, clearTokens } from "./authStorage";

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 15000,
});

api.interceptors.request.use(async (config) => {
  const isAuthEndpoint = config.url?.startsWith("/auth/");
  if (!isAuthEndpoint) {
    const accessToken = await getAccessToken();
    if (accessToken) {
      config.headers.set("Authorization", `Bearer ${accessToken}`);
    }
  }
  return config;
});

// True only when the server explicitly rejected the credentials. Network
// errors, timeouts and 5xx are transient and must not destroy the session.
export function isAuthRejection(error: unknown): boolean {
  const status = axios.isAxiosError(error) ? error.response?.status : undefined;
  return status === 401 || status === 403;
}

// Coalesce concurrent 401s (e.g. two screens fire requests at once) into one refresh call.
let refreshPromise: Promise<string | null> | null = null;

// Resolves to null if the session is dead (no token or server rejected it);
// throws on transient failures so callers keep the tokens.
async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = await getRefreshToken();
  if (!refreshToken) return null;
  try {
    // Plain axios call (not `api`) — avoids recursing through these same interceptors.
    const { data } = await axios.post(`${API_BASE_URL}/auth/refresh`, { refreshToken });
    await setTokens({ accessToken: data.accessToken, refreshToken });
    return data.accessToken as string;
  } catch (e) {
    if (isAuthRejection(e)) return null;
    throw e;
  }
}

type RetryableConfig = InternalAxiosRequestConfig & { _retry?: boolean };

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const original = error.config as RetryableConfig | undefined;
    const isAuthEndpoint = original?.url?.startsWith("/auth/");

    if (error.response?.status === 401 && original && !original._retry && !isAuthEndpoint) {
      original._retry = true;

      if (!refreshPromise) {
        refreshPromise = refreshAccessToken().finally(() => {
          refreshPromise = null;
        });
      }
      let newAccessToken: string | null;
      try {
        newAccessToken = await refreshPromise;
      } catch {
        // Transient failure (offline, timeout, 5xx) — keep the session.
        return Promise.reject(error);
      }

      if (newAccessToken) {
        original.headers.set("Authorization", `Bearer ${newAccessToken}`);
        return api(original);
      }

      // Refresh itself failed — the session is dead. Clear local tokens and
      // force the user back to the phone screen. `router` here is
      // expo-router's importable singleton, usable outside any component.
      await clearTokens();
      router.replace("/(auth)/phone");
    }

    return Promise.reject(error);
  }
);
