import { Navigate, NavLink, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../lib/auth-context.tsx";
import { roleLabel } from "../lib/format.ts";

const NAV: { to: string; label: string; end?: boolean; needs?: "team.manage" | "audit.read" }[] = [
  { to: "/", label: "Dashboard", end: true },
  { to: "/vendors", label: "Vendors" },
  { to: "/categories", label: "Categories" },
  { to: "/families", label: "Families" },
  { to: "/events", label: "Events" },
  { to: "/roadmap", label: "Roadmap" },
  { to: "/audit", label: "Audit", needs: "audit.read" },
  { to: "/team", label: "Team", needs: "team.manage" },
  { to: "/account", label: "Account" },
];

export function Layout() {
  const { state, admin, signOut, retry, can } = useAuth();
  const { pathname } = useLocation();

  if (state === "loading") return <p className="page-status">Loading…</p>;
  if (state === "unauthed") return <Navigate to="/login" replace />;
  if (state === "error" || !admin) {
    return (
      <div className="centered-page">
        <div className="card" role="alert">
          <h1>Can’t reach the server</h1>
          <p>Your session is still saved. Check your connection and try again.</p>
          <button type="button" onClick={retry}>Try again</button>
        </div>
      </div>
    );
  }
  if (admin.mustChangePassword && pathname !== "/account") return <Navigate to="/account" replace />;

  return (
    <>
      <a className="skip-link" href="#main">Skip to content</a>
      <header className="topbar">
        <strong className="brand">Sanchalan Admin</strong>
        {!admin.mustChangePassword && (
          <nav aria-label="Main">
            {NAV.filter((n) => !n.needs || can(n.needs)).map((n) => (
              <NavLink key={n.to} to={n.to} end={n.end ?? false} className={({ isActive }) => (isActive ? "nav-link nav-active" : "nav-link")}>
                {n.label}
              </NavLink>
            ))}
          </nav>
        )}
        <div className="topbar-user">
          <span>
            {admin.name} <span className="badge badge-neutral">{roleLabel(admin.role)}</span>
          </span>
          <button type="button" className="secondary" onClick={() => signOut()}>
            Log out
          </button>
        </div>
      </header>
      <main id="main">
        <Outlet />
      </main>
    </>
  );
}
