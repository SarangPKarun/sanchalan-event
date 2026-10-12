import { useState, type FormEvent } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import axios from "axios";
import type { AuthTokens } from "@sanchalan/shared-types";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { BrandMark } from "../components/icons.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

export function LoginPage() {
  usePageTitle("Sign in");
  const { state, signIn, notice } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (state === "authed") return <Navigate to="/" replace />;

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const { data } = await api.post<AuthTokens>("/admin/auth/login", { email, password });
      await signIn(data);
      navigate("/", { replace: true });
    } catch (err) {
      const status = axios.isAxiosError(err) ? err.response?.status : undefined;
      if (status === 401) setError("Invalid email or password.");
      else if (status === 429)
        setError((err as { response?: { data?: { error?: string } } }).response?.data?.error ?? "Too many attempts. Try again later.");
      else setError("Something went wrong. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="centered-page login-page">
      <form className="card login-form" onSubmit={handleSubmit}>
        <div className="brand"><BrandMark /></div>
        <h1>Sanchalan Admin</h1>
        <p className="muted">Sign in to continue.</p>
        {notice && <p className="notice">{notice}</p>}
        <label>
          Email
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoFocus autoComplete="username" />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required autoComplete="current-password" />
        </label>
        {error && (
          <p className="error-text" role="alert">
            {error}
          </p>
        )}
        <button type="submit" disabled={submitting}>
          {submitting ? "Logging in…" : "Log in"}
        </button>
      </form>
    </div>
  );
}
