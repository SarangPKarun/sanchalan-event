import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { AuthTokens } from "@sanchalan/shared-types";
import { api, SESSION_EXPIRED_EVENT } from "./api.ts";
import { getRefreshToken, setTokens, clearTokens } from "./authStorage.ts";

type AuthState = "loading" | "authed" | "unauthed";

interface AuthContextValue {
  state: AuthState;
  signIn: (tokens: AuthTokens) => void;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>("loading");

  useEffect(() => {
    const onSessionExpired = () => setState("unauthed");
    window.addEventListener(SESSION_EXPIRED_EVENT, onSessionExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onSessionExpired);
  }, []);

  useEffect(() => {
    (async () => {
      const refreshToken = getRefreshToken();
      if (!refreshToken) {
        setState("unauthed");
        return;
      }
      try {
        const { data } = await api.post("/auth/refresh", { refreshToken });
        setTokens({ accessToken: data.accessToken, refreshToken });
        setState("authed");
      } catch {
        clearTokens();
        setState("unauthed");
      }
    })();
  }, []);

  function signIn(tokens: AuthTokens) {
    setTokens(tokens);
    setState("authed");
  }

  async function signOut() {
    const refreshToken = getRefreshToken();
    try {
      if (refreshToken) await api.post("/auth/logout", { refreshToken });
    } catch {
      // best-effort — clear local state regardless
    } finally {
      clearTokens();
      setState("unauthed");
    }
  }

  return <AuthContext.Provider value={{ state, signIn, signOut }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
