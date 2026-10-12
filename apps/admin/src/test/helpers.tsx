import type { ReactElement } from "react";
import { render } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { api } from "./mock-api.ts";
import { AuthProvider, type AdminMe } from "../lib/auth-context.tsx";
import { ToastProvider } from "../lib/toast.tsx";

export { api };

export function admin(role: AdminMe["role"], over: Partial<AdminMe> = {}): AdminMe {
  const reviewer = ["vendor.review", "category.review", "category.manage", "review.moderate"] as const;
  const permissions = role === "super_admin" ? [...reviewer, "organizer.manage", "team.manage", "audit.read"] : role === "vendor_reviewer" ? [...reviewer] : [];
  return { id: "a1", name: "Test Admin", email: "t@x.com", role, mustChangePassword: false, permissions: permissions as AdminMe["permissions"], ...over };
}

/** Routes the mocked api: /admin/me returns `me`, everything else is looked up in `routes`. */
export function mockApi(me: AdminMe, routes: Record<string, unknown> = {}) {
  api.get.mockImplementation(async (url: string) => {
    if (url === "/admin/me") return { data: me };
    if (url in routes) return { data: routes[url] };
    throw Object.assign(new Error("no mock for " + url), { response: { status: 404 } });
  });
  api.post.mockImplementation(async (url: string) => {
    if (url === "/auth/refresh") return { data: { accessToken: "t" } };
    return { data: {} };
  });
}

export function renderApp(ui: ReactElement, path = "/") {
  localStorage.setItem("sanchalan.admin.refreshToken", "r");
  return render(
    <MemoryRouter initialEntries={[path]}>
      <ToastProvider>
        <AuthProvider>{ui}</AuthProvider>
      </ToastProvider>
    </MemoryRouter>
  );
}
