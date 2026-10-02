import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { api, isAuthRejection } from "./api";
import { getRefreshToken, setTokens, clearTokens, getRole, setRole as persistRole } from "./authStorage";
import type { AuthTokens, Role } from "./types";

type AuthState = "loading" | "authed" | "unauthed";

type AuthContextValue = {
  state: AuthState;
  role: Role | null;
  signIn: (tokens: AuthTokens, role: Role) => Promise<void>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>("loading");
  const [role, setRole] = useState<Role | null>(null);

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
        // /auth/refresh only returns a new accessToken — role isn't
        // re-issued there, so it's read back from where signIn persisted it.
        setRole(await getRole());
        setState("authed");
      } catch (e) {
        if (isAuthRejection(e)) {
          await clearTokens();
          setState("unauthed");
          return;
        }
        // Transient failure (offline, timeout, 5xx): keep the stored session
        // and enter the app; the 401 interceptor refreshes lazily later.
        const cachedRole = await getRole();
        if (cachedRole) {
          setRole(cachedRole);
          setState("authed");
        } else {
          setState("unauthed");
        }
      }
    })();
  }, []);

  async function signIn(tokens: AuthTokens, newRole: Role) {
    await setTokens(tokens);
    await persistRole(newRole);
    setRole(newRole);
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
      setRole(null);
      setState("unauthed");
    }
  }

  return (
    <AuthContext.Provider value={{ state, role, signIn, signOut }}>{children}</AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
