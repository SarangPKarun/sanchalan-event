import { useState } from "react";
import { Navigate, NavLink, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../lib/auth-context.tsx";
import { roleLabel } from "../lib/format.ts";
import { BrandMark, Icon, type IconName } from "./icons.tsx";

type Needs = "team.manage" | "audit.read";
interface NavItem {
  to: string;
  label: string;
  icon: IconName;
  end?: boolean;
  needs?: Needs;
}

const NAV_GROUPS: { title: string; items: NavItem[] }[] = [
  { title: "Overview", items: [{ to: "/", label: "Dashboard", icon: "dashboard", end: true }] },
  {
    title: "Marketplace",
    items: [
      { to: "/vendors", label: "Vendors", icon: "vendors" },
      { to: "/categories", label: "Categories", icon: "categories" },
      { to: "/families", label: "Families", icon: "families" },
      { to: "/events", label: "Events", icon: "events" },
    ],
  },
  {
    title: "Operations",
    items: [
      { to: "/bookings", label: "Bookings", icon: "bookings" },
      { to: "/reviews", label: "Reviews", icon: "reviews" },
      { to: "/roadmap", label: "Roadmap", icon: "roadmap" },
    ],
  },
  {
    title: "Administration",
    items: [
      { to: "/audit", label: "Audit", icon: "audit", needs: "audit.read" },
      { to: "/team", label: "Team", icon: "team", needs: "team.manage" },
      { to: "/account", label: "Account", icon: "account" },
    ],
  },
];

export function Layout() {
  const { state, admin, signOut, retry, can } = useAuth();
  const { pathname } = useLocation();
  const [open, setOpen] = useState(false);

  if (state === "loading")
    return (
      <div className="centered-page">
        <p className="page-status">Loading…</p>
      </div>
    );
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

  const showNav = !admin.mustChangePassword;

  return (
    <div className="shell">
      <a className="skip-link" href="#main">Skip to content</a>
      <header className="mobilebar">
        {showNav && (
          <button type="button" className="icon-button" aria-label="Toggle menu" aria-expanded={open} onClick={() => setOpen((o) => !o)}>
            <Icon name={open ? "close" : "menu"} size={20} />
          </button>
        )}
        <span className="brand">
          <BrandMark />
          Sanchalan Admin
        </span>
      </header>
      {open && <div className="scrim" onClick={() => setOpen(false)} />}
      <aside className={open ? "sidebar sidebar-open" : "sidebar"}>
        <div className="brand">
          <BrandMark />
          <span>Sanchalan Admin</span>
        </div>
        {showNav && (
          <nav aria-label="Main" onClick={() => setOpen(false)}>
            {NAV_GROUPS.map((g) => {
              const items = g.items.filter((n) => !n.needs || can(n.needs));
              if (items.length === 0) return null;
              return (
                <div className="nav-group" key={g.title}>
                  <div className="nav-heading">{g.title}</div>
                  {items.map((n) => (
                    <NavLink key={n.to} to={n.to} end={n.end ?? false} className={({ isActive }) => (isActive ? "nav-link nav-active" : "nav-link")}>
                      <Icon name={n.icon} />
                      {n.label}
                    </NavLink>
                  ))}
                </div>
              );
            })}
          </nav>
        )}
        <div className="sidebar-user">
          <span className="avatar" aria-hidden="true">{admin.name.charAt(0).toUpperCase()}</span>
          <div className="sidebar-user-info">
            <strong>{admin.name}</strong>
            <span className="badge badge-neutral">{roleLabel(admin.role)}</span>
          </div>
          <button type="button" className="icon-button" aria-label="Log out" title="Log out" onClick={() => signOut()}>
            <Icon name="logout" />
          </button>
        </div>
      </aside>
      <main id="main">
        <Outlet />
      </main>
    </div>
  );
}
