import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../lib/auth-context.tsx";

export function ProtectedLayout() {
  const { state } = useAuth();

  if (state === "loading") return <p className="page-status">Loading…</p>;
  if (state === "unauthed") return <Navigate to="/login" replace />;

  return <Outlet />;
}
