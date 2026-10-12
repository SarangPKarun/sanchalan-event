import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import axios from "axios";
import type { AuthTokens } from "@sanchalan/shared-types";
import { api, SESSION_EXPIRED_EVENT } from "./api.ts";
import { getRefreshToken, setTokens, clearTokens } from "./authStorage.ts";

export type AdminAction =
  | "vendor.review"
  | "category.review"
  | "category.manage"
  | "organizer.manage"
  | "review.moderate"
  | "team.manage"
  | "audit.read";

export interface AdminMe {
  id: string;
  name: string;
  email: string;
  role: "super_admin" | "vendor_reviewer" | "support";
  mustChangePassword: boolean;
  permissions: AdminAction[];
}

/** "error" means the server could not be reached; the session itself may still be valid. */
type AuthState = "loading" | "authed" | "unauthed" | "error";

interface AuthContextValue {
  state: AuthState;
  admin: AdminMe | null;
  /** Why the admin was signed out, shown on the login page. */
  notice: string | null;
  signIn: (tokens: Pick<AuthTokens, "accessToken" | "refreshToken">) => Promise<void>;
  /** Stores new tokens (after a password change) and reloads the admin. */
  replaceTokens: (tokens: Pick<AuthTokens, "accessToken" | "refreshToken">) => Promise<void>;
  signOut: () => Promise<void>;
  signOutEverywhere: () => Promise<void>;
  retry: () => void;
  can: (action: AdminAction) => boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

const isUnauthorized = (err: unknown) => axios.isAxiosError(err) && err.response?.status === 401;

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>("loading");
  const [admin, setAdmin] = useState<AdminMe | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  const loadMe = useCallback(async () => {
    const { data } = await api.get<AdminMe>("/admin/me");
    setAdmin(data);
    setState("authed");
  }, []);

  useEffect(() => {
    const onSessionExpired = () => {
      setAdmin(null);
      setNotice("Your session expired. Please sign in again.");
      setState("unauthed");
    };
    window.addEventListener(SESSION_EXPIRED_EVENT, onSessionExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onSessionExpired);
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const refreshToken = getRefreshToken();
      if (!refreshToken) {
        setState("unauthed");
        return;
      }
      try {
        const { data } = await api.post("/auth/refresh", { refreshToken });
        setTokens({ accessToken: data.accessToken, refreshToken });
        await loadMe();
      } catch (err) {
        if (cancelled) return;
        if (isUnauthorized(err)) {
          clearTokens();
          setState("unauthed");
        } else {
          // Network blip or server error: keep the session and let the admin retry.
          setState("error");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [loadMe, attempt]);

  const signIn: AuthContextValue["signIn"] = async (tokens) => {
    setTokens(tokens);
    setNotice(null);
    await loadMe();
  };

  async function signOut() {
    const refreshToken = getRefreshToken();
    try {
      if (refreshToken) await api.post("/auth/logout", { refreshToken });
    } catch {
      // best-effort: clear local state regardless
    } finally {
      clearTokens();
      setAdmin(null);
      setState("unauthed");
    }
  }

  async function signOutEverywhere() {
    try {
      await api.post("/admin/me/logout-all");
    } finally {
      clearTokens();
      setAdmin(null);
      setState("unauthed");
    }
  }

  const value: AuthContextValue = {
    state,
    admin,
    notice,
    signIn,
    replaceTokens: signIn,
    signOut,
    signOutEverywhere,
    retry: () => {
      setState("loading");
      setAttempt((n) => n + 1);
    },
    can: (action) => admin?.permissions.includes(action) ?? false,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
