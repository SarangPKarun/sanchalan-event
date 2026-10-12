import { describe, expect, it, vi, beforeEach } from "vitest";
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Route, Routes } from "react-router-dom";
import { api, admin, mockApi, renderApp } from "./helpers.tsx";

vi.mock("../lib/api.ts", async () => {
  const { api: mocked } = await import("./mock-api.ts");
  return { api: mocked, SESSION_EXPIRED_EVENT: "session-expired" };
});

import { App } from "../App.tsx";
import { Layout } from "../components/Layout.tsx";
import { Tabs } from "../components/Tabs.tsx";
import { VendorProvider } from "../lib/vendor-context.tsx";

const VENDOR = {
  id: "v1",
  businessName: "Lotus Decor",
  phoneNumber: "+919999999999",
  status: "pending_review",
  priceTier: "premium",
  vendorVendorCategories: [],
  portfolioItems: [],
  reviewLogs: [],
};

function renderRoutes(path: string) {
  return renderApp(
    <VendorProvider>
      <App />
    </VendorProvider>,
    path
  );
}

beforeEach(() => {
  api.get.mockReset();
  api.post.mockReset();
  api.patch.mockReset();
  localStorage.clear();
});

describe("auth gating and shell", () => {
  it("sends a signed-out visitor to the login page", async () => {
    mockApi(admin("support"));
    api.post.mockRejectedValue(Object.assign(new Error("401"), { isAxiosError: true, response: { status: 401 } }));
    renderRoutes("/vendors");
    expect(await screen.findByRole("button", { name: "Log in" })).toBeInTheDocument();
  });

  it("keeps the session when the server is unreachable and offers a retry", async () => {
    mockApi(admin("support"));
    api.post.mockRejectedValue(new Error("Network Error"));
    renderRoutes("/vendors");
    expect(await screen.findByText("Can’t reach the server")).toBeInTheDocument();
    expect(localStorage.getItem("sanchalan.admin.refreshToken")).toBe("r");
  });

  it("shows name, role and only the nav items the role may use", async () => {
    mockApi(admin("support"), { "/admin/vendors": { vendors: [] } });
    renderRoutes("/vendors");
    expect(await screen.findByText("Test Admin")).toBeInTheDocument();
    const nav = screen.getByRole("navigation", { name: "Main" });
    expect(within(nav).queryByText("Team")).not.toBeInTheDocument();
    expect(within(nav).getByText("Vendors")).toBeInTheDocument();
  });

  it("shows the team link to super admins", async () => {
    mockApi(admin("super_admin"), { "/admin/vendors": { vendors: [] } });
    renderRoutes("/vendors");
    expect(await within(await screen.findByRole("navigation", { name: "Main" })).findByText("Team")).toBeInTheDocument();
  });

  it("forces a temporary password to be replaced before anything else", async () => {
    mockApi(admin("super_admin", { mustChangePassword: true }), { "/admin/vendors": { vendors: [] } });
    renderRoutes("/vendors");
    expect(await screen.findByText(/temporary password/i)).toBeInTheDocument();
    expect(screen.queryByRole("navigation", { name: "Main" })).not.toBeInTheDocument();
  });

  it("shows a not-found page for unknown routes", async () => {
    mockApi(admin("support"));
    renderRoutes("/nope");
    expect(await screen.findByText("Page not found")).toBeInTheDocument();
  });

  it("blocks the team page for non-super admins", async () => {
    mockApi(admin("vendor_reviewer"));
    renderRoutes("/team");
    expect(await screen.findByText("Only super admins can manage the team.")).toBeInTheDocument();
    expect(api.get).not.toHaveBeenCalledWith("/admin/admins");
  });
});

describe("vendor review actions", () => {
  it("hides review buttons from support admins", async () => {
    mockApi(admin("support"), { "/admin/vendors/v1": VENDOR });
    renderRoutes("/vendors/v1");
    expect(await screen.findByRole("heading", { name: /Lotus Decor/ })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Approve" })).not.toBeInTheDocument();
    expect(screen.getByText(/can view vendors but not review/i)).toBeInTheDocument();
  });

  it("asks for confirmation before approving", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/vendors/v1": VENDOR });
    renderRoutes("/vendors/v1");
    await userEvent.click(await screen.findByRole("button", { name: "Approve" }));
    expect(api.post).not.toHaveBeenCalledWith("/admin/vendors/v1/approve", undefined);
    const dialog = screen.getByRole("dialog");
    await userEvent.click(within(dialog).getByRole("button", { name: "Approve" }));
    await waitFor(() => expect(api.post).toHaveBeenCalledWith("/admin/vendors/v1/approve", undefined));
    expect(await screen.findByText("Vendor approved.")).toBeInTheDocument();
  });

  it("requires a reason to reject", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/vendors/v1": VENDOR, "/admin/vendors": { vendors: [] } });
    renderRoutes("/vendors/v1");
    await userEvent.click(await screen.findByRole("button", { name: "Reject" }));
    const dialog = screen.getByRole("dialog");
    const confirm = within(dialog).getByRole("button", { name: "Reject" });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole("textbox"), "Missing photos");
    expect(confirm).toBeEnabled();
    await userEvent.click(confirm);
    await waitFor(() => expect(api.post).toHaveBeenCalledWith("/admin/vendors/v1/reject", { reason: "Missing photos" }));
  });

  it("shows the server's message when a decision loses a race", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/vendors/v1": VENDOR });
    api.post.mockImplementation(async (url: string) => {
      if (url === "/auth/refresh") return { data: { accessToken: "t" } };
      throw Object.assign(new Error("409"), { response: { status: 409, data: { error: "Vendor must be pending review to approve" } } });
    });
    renderRoutes("/vendors/v1");
    await userEvent.click(await screen.findByRole("button", { name: "Approve" }));
    await userEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Approve" }));
    expect(await screen.findByText("Vendor must be pending review to approve")).toBeInTheDocument();
  });
});

describe("Tabs", () => {
  it("is an ARIA tablist that moves with the arrow keys", async () => {
    const onChange = vi.fn();
    const { rerender } = renderApp(
      <Tabs label="Status" value="a" onChange={onChange} tabs={[{ value: "a", label: "A" }, { value: "b", label: "B", count: 3 }]} />
    );
    expect(screen.getByRole("tab", { name: "A" })).toHaveAttribute("aria-selected", "true");
    await userEvent.click(screen.getByRole("tab", { name: "A" }));
    await userEvent.keyboard("{ArrowRight}");
    expect(onChange).toHaveBeenCalledWith("b");
    rerender(<></>);
  });
});

describe("layout export", () => {
  it("is routable", () => {
    expect(Layout).toBeTypeOf("function");
    expect(Routes).toBeTypeOf("function");
    expect(Route).toBeTypeOf("function");
  });
});
