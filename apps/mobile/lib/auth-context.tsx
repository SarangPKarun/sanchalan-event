import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { api } from "./api";
import { getRefreshToken, setTokens, clearTokens } from "./authStorage";
import type { AuthTokens } from "./types";

type AuthState = "loading" | "authed" | "unauthed";

type AuthContextValue = {
  state: AuthState;
  signIn: (tokens: AuthTokens) => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>("loading");

  useEffect(() => {
    (async () => {
      const refreshToken = await getRefreshToken();
      if (!refreshToken) {
        setState("unauthed");
        return;
      }
      try {
        const { data } = await api.post("/auth/refresh", { refreshToken });
        await setTokens({ accessToken: data.accessToken, refreshToken });
        setState("authed");
      } catch {
        // Covers both "refresh token invalid/revoked" and network errors.
        // Simplest-correct behavior for v1: treat any failure as logged out.
        // This means launching fully offline with a valid token still shows
        // the login screen — acceptable trade-off for now.
        await clearTokens();
        setState("unauthed");
      }
    })();
  }, []);

  async function signIn(tokens: AuthTokens) {
    await setTokens(tokens);
    setState("authed");
  }

  async function signOut() {
    const refreshToken = await getRefreshToken();
    try {
      if (refreshToken) await api.post("/auth/logout", { refreshToken });
    } catch {
      // best-effort — clear local state regardless
    } finally {
      await clearTokens();
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
