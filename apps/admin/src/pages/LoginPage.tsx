import { useState, type FormEvent } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import axios from "axios";
import type { AuthTokens } from "@sanchalan/shared-types";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";

export function LoginPage() {
  const { state, signIn } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (state === "authed") return <Navigate to="/vendors" replace />;

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const { data } = await api.post<AuthTokens>("/admin/auth/login", { email, password });
      signIn(data);
      navigate("/vendors", { replace: true });
    } catch (err) {
      if (axios.isAxiosError(err) && err.response?.status === 401) {
        setError("Invalid email or password.");
      } else {
        setError("Something went wrong. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="centered-page">
      <form className="card login-form" onSubmit={handleSubmit}>
        <h1>Sanchalan Admin</h1>
        <label>
          Email
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            autoFocus
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>
        {error && <p className="error-text">{error}</p>}
        <button type="submit" disabled={submitting}>
          {submitting ? "Logging in…" : "Log in"}
        </button>
      </form>
    </div>
  );
}
