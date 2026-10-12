import { beforeEach, describe, expect, it, vi } from "vitest";
import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { api, admin, mockApi, renderApp } from "./helpers.tsx";

vi.mock("../lib/api.ts", async () => {
  const { api: mocked } = await import("./mock-api.ts");
  return { api: mocked, SESSION_EXPIRED_EVENT: "session-expired" };
});

import { App } from "../App.tsx";
import { VendorProvider } from "../lib/vendor-context.tsx";

const NOW = new Date().toISOString();
const STATS = {
  vendors: { draft: 0, pending_review: 3, published: 12, rejected: 0, suspended: 0 },
  proposals: { pending: 1, approved: 0, rejected: 0, merged: 0 },
  organizers: 40,
  events: 25,
  roadmaps: { lastSevenDays: 6, total: 30, failedLastSevenDays: 2, tokensLastThirtyDays: { input: 12000, output: 8000 } },
  oldestPending: { vendor: { id: "v1", businessName: "Old Vendor", submittedAt: new Date(Date.now() - 3 * 86400000).toISOString() }, proposal: null },
};
const ORGANIZER = {
  id: "o1",
  displayName: "Sharma Family",
  phoneNumber: "+919000000001",
  email: null,
  organizerType: "family",
  status: "active",
  createdAt: NOW,
  suspension: null,
  eventGroups: [],
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
  for (const f of Object.values(api)) f.mockReset();
  localStorage.clear();
});

describe("dashboard", () => {
  it("surfaces queues, their age and failed roadmaps", async () => {
    mockApi(admin("super_admin"), { "/admin/stats": STATS, "/admin/audit-logs": { entries: [] } });
    renderRoutes("/");
    expect(await screen.findByText("Vendors awaiting review")).toBeInTheDocument();
    expect(screen.getByText("oldest waiting 3 days ago")).toBeInTheDocument();
    expect(screen.getByText("Failed roadmaps (7 days)").closest("a")).toHaveAttribute("href", "/roadmap?status=failed");
    expect(screen.getByText("20,000")).toBeInTheDocument();
  });

  it("hides recent activity from admins who cannot read the audit log", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/stats": STATS });
    renderRoutes("/");
    await screen.findByText("Vendors awaiting review");
    expect(screen.queryByText("Recent activity")).not.toBeInTheDocument();
    expect(api.get).not.toHaveBeenCalledWith("/admin/audit-logs", expect.anything());
    expect(within(screen.getByRole("navigation", { name: "Main" })).queryByText("Audit")).not.toBeInTheDocument();
  });
});

describe("families", () => {
  it("suspends a family only after a reason is given", async () => {
    mockApi(admin("super_admin"), { "/admin/organizers/o1": ORGANIZER });
    renderRoutes("/families/o1");
    await userEvent.click(await screen.findByRole("button", { name: "Suspend" }));
    const dialog = screen.getByRole("dialog");
    const confirm = within(dialog).getByRole("button", { name: "Suspend" });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole("textbox"), "Abuse reports");
    await userEvent.click(confirm);
    await waitFor(() => expect(api.post).toHaveBeenCalledWith("/admin/organizers/o1/suspend", { reason: "Abuse reports" }));
    expect(await screen.findByText("Family suspended. They are signed out.")).toBeInTheDocument();
  });

  it("shows the recorded reason and offers to restore a suspended family", async () => {
    const suspended = { ...ORGANIZER, status: "suspended", suspension: { metadata: { reason: "Abuse reports" }, createdAt: NOW, admin: { name: "Seed Admin" } } };
    mockApi(admin("super_admin"), { "/admin/organizers/o1": suspended });
    renderRoutes("/families/o1");
    expect(await screen.findByText(/Abuse reports · by Seed Admin/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Restore access" })).toBeInTheDocument();
  });

  it("lets reviewers view a family but not suspend it", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/organizers/o1": ORGANIZER });
    renderRoutes("/families/o1");
    expect(await screen.findByRole("heading", { name: /Sharma Family/ })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Suspend" })).not.toBeInTheDocument();
  });
});

describe("roadmap review", () => {
  it("lists failed generations with their error", async () => {
    mockApi(admin("support"), {
      "/admin/roadmap-logs": {
        logs: [
          { id: "l1", status: "failed", error: "LLM failed to produce a valid roadmap", createdAt: NOW, llmModelUsed: "m", latencyMs: 4200, attempts: 2, inputTokens: 1000, outputTokens: 500, eventGroup: { id: "e1", name: "Riya & Arjun" } },
        ],
        total: 1,
        page: 1,
        pageSize: 20,
      },
    });
    renderRoutes("/roadmap?status=failed");
    expect(await screen.findByText("Riya & Arjun")).toBeInTheDocument();
    expect(screen.getByText("LLM failed to produce a valid roadmap")).toBeInTheDocument();
    expect(screen.getByText(/1500 tokens · 4.2s · 2 attempts/)).toBeInTheDocument();
    expect(screen.getByText("Failed", { selector: ".badge" })).toBeInTheDocument();
  });

  it("shows which template tasks families change most", async () => {
    mockApi(admin("support"), {
      "/admin/task-edit-stats": { days: 90, byAction: { edited: 5, marked_not_applicable: 2 }, truncated: false, topChanged: [{ name: "Book venue", category: "venue", edited: 5, removed: 2, statusChanged: 0, total: 7 }] },
    });
    renderRoutes("/roadmap/feedback");
    expect(await screen.findByText("Book venue")).toBeInTheDocument();
    expect(screen.getByText("5 edited · 2 removed")).toBeInTheDocument();
  });
});

describe("audit log", () => {
  it("lists entries and links them to what changed", async () => {
    mockApi(admin("super_admin"), {
      "/admin/audit-logs": {
        entries: [{ id: "a1", action: "vendor.approved", entityType: "vendor", entityId: "v1", metadata: null, ip: null, createdAt: NOW, admin: { id: "x", name: "Seed Admin" } }],
        total: 1,
        page: 1,
        pageSize: 20,
      },
    });
    renderRoutes("/audit");
    expect(await screen.findByText("vendor.approved")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "open" })).toHaveAttribute("href", "/vendors/v1");
  });
});
