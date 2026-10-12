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

const vendor = (id: string, name: string) => ({
  id,
  businessName: name,
  phoneNumber: `+91${id}`,
  status: "pending_review",
  priceTier: "standard",
  serviceArea: "Pune",
  submittedAt: "2026-10-01T00:00:00Z",
  vendorVendorCategories: [],
  portfolioItems: [],
});

const STATS = {
  vendors: { draft: 1, pending_review: 2, published: 5, rejected: 0, suspended: 0 },
  proposals: { pending: 3, approved: 0, rejected: 0, merged: 0 },
};

const CATEGORIES = {
  categories: [
    { categoryKey: "venue", vendorCategoryId: "vc1", label: null, isActive: true, applicableEventTypes: ["wedding"], vendorCount: 4, templateCount: 1 },
    { categoryKey: "decor", vendorCategoryId: "vc2", label: "Décor", isActive: true, applicableEventTypes: ["wedding"], vendorCount: 2, templateCount: 0 },
  ],
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

describe("vendor queue", () => {
  const routes = {
    "/admin/vendors": { vendors: [vendor("1", "Alpha Caterers"), vendor("2", "Beta Decor")], total: 45, page: 1, pageSize: 20 },
    "/admin/stats": STATS,
    "/admin/vendor-categories": CATEGORIES,
  };

  it("shows status counts on the tabs and pagination for large lists", async () => {
    mockApi(admin("vendor_reviewer"), routes);
    renderRoutes("/vendors");
    expect(await screen.findByRole("tab", { name: /Pending review\s*2/ })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: /Published\s*5/ })).toBeInTheDocument();
    expect(await screen.findByText("1–20 of 45")).toBeInTheDocument();
    expect(screen.getByText("Page 1 of 3")).toBeInTheDocument();
  });

  it("asks the server for the next page and keeps it in the URL", async () => {
    mockApi(admin("vendor_reviewer"), routes);
    renderRoutes("/vendors");
    await userEvent.click(await screen.findByRole("button", { name: "Next" }));
    await waitFor(() =>
      expect(api.get).toHaveBeenCalledWith("/admin/vendors", expect.objectContaining({ params: expect.objectContaining({ page: 2 }) }))
    );
  });

  it("bulk-approves the selected vendors after a confirmation", async () => {
    mockApi(admin("vendor_reviewer"), routes);
    api.post.mockImplementation(async (url: string) => {
      if (url === "/auth/refresh") return { data: { accessToken: "t" } };
      return { data: { results: [{ id: "1", ok: true }, { id: "2", ok: true }] } };
    });
    renderRoutes("/vendors");
    await userEvent.click(await screen.findByLabelText("Select all on this page"));
    await userEvent.click(screen.getByRole("button", { name: "Approve selected" }));
    expect(api.post).not.toHaveBeenCalledWith("/admin/vendors/bulk", expect.anything());
    await userEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Approve" }));
    await waitFor(() =>
      expect(api.post).toHaveBeenCalledWith("/admin/vendors/bulk", { action: "approve", ids: ["1", "2"] })
    );
    expect(await screen.findByText("2 vendors approved.")).toBeInTheDocument();
  });

  it("reports vendors that could not be decided", async () => {
    mockApi(admin("vendor_reviewer"), routes);
    api.post.mockImplementation(async (url: string) => {
      if (url === "/auth/refresh") return { data: { accessToken: "t" } };
      return { data: { results: [{ id: "1", ok: true }, { id: "2", ok: false, error: "Vendor must be pending review to approve" }] } };
    });
    renderRoutes("/vendors");
    await userEvent.click(await screen.findByLabelText("Select all on this page"));
    await userEvent.click(screen.getByRole("button", { name: "Approve selected" }));
    await userEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Approve" }));
    expect(await screen.findByText(/1 failed: Vendor must be pending review/)).toBeInTheDocument();
  });

  it("gives support admins no selection or bulk controls", async () => {
    mockApi(admin("support"), routes);
    renderRoutes("/vendors");
    expect(await screen.findByText("Alpha Caterers")).toBeInTheDocument();
    expect(screen.queryByLabelText("Select all on this page")).not.toBeInTheDocument();
  });
});

describe("categories", () => {
  const TEMPLATE = {
    id: "t1",
    eventType: "wedding",
    taskKey: "book_venue",
    defaultNameEn: "Book venue",
    defaultLeadTimeDays: 180,
    defaultDependencyKeys: [],
    typicalOwnerType: "organizer",
    version: 1,
  };

  it("lists categories with vendor and task counts", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/categories": CATEGORIES, "/admin/stats": STATS });
    renderRoutes("/categories");
    expect(await screen.findByText("Décor")).toBeInTheDocument();
    expect(screen.getByText(/4 vendors · 1 starter task/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Proposals\s*3/ })).toBeInTheDocument();
  });

  it("edits a starter task and sends the change", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/categories": CATEGORIES, "/admin/task-templates": { templates: [TEMPLATE] } });
    api.patch.mockResolvedValue({ data: {} });
    renderRoutes("/categories/venue");
    await userEvent.click(await screen.findByRole("button", { name: "Edit" }));
    const dialog = screen.getByRole("dialog");
    const lead = within(dialog).getByLabelText(/Lead time/);
    await userEvent.clear(lead);
    await userEvent.type(lead, "200");
    await userEvent.click(within(dialog).getByRole("button", { name: "Save task" }));
    await waitFor(() =>
      expect(api.patch).toHaveBeenCalledWith(
        "/admin/task-templates/t1",
        expect.objectContaining({ taskKey: "book_venue", defaultLeadTimeDays: 200, defaultDependencyKeys: [] })
      )
    );
  });

  it("shows the server's reason when a task cannot be deleted", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/categories": CATEGORIES, "/admin/task-templates": { templates: [TEMPLATE] } });
    api.delete.mockRejectedValue({ response: { status: 409, data: { error: "Used as a dependency by: pick_decor" } } });
    renderRoutes("/categories/venue");
    await userEvent.click(await screen.findByRole("button", { name: "Delete" }));
    await userEvent.click(within(screen.getByRole("dialog", { name: /Delete/ })).getByRole("button", { name: "Delete" }));
    expect(await screen.findByText("Used as a dependency by: pick_decor")).toBeInTheDocument();
  });

  it("hides editing from support admins", async () => {
    mockApi(admin("support"), { "/admin/categories": CATEGORIES, "/admin/task-templates": { templates: [TEMPLATE] } });
    renderRoutes("/categories/venue");
    expect(await screen.findByText("Book venue")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Edit" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Add task" })).not.toBeInTheDocument();
  });

  it("previews who a merge affects before confirming", async () => {
    const proposal = {
      id: "p1",
      label: "Photographer",
      categoryKey: "photographer",
      description: null,
      status: "pending",
      rejectionReason: null,
      submittedAt: "2026-10-01T00:00:00Z",
      vendors: [{ vendor: { id: "v1", businessName: "Lens Co", phoneNumber: "+911" } }],
      resolvedCategory: null,
    };
    mockApi(admin("vendor_reviewer"), {
      "/admin/category-proposals": { proposals: [proposal], total: 1, page: 1, pageSize: 20 },
      "/admin/categories": CATEGORIES,
      "/admin/stats": STATS,
    });
    renderRoutes("/categories/proposals");
    await userEvent.click(await screen.findByRole("button", { name: "Merge into existing…" }));
    await userEvent.selectOptions(screen.getByLabelText("Existing category"), "venue");
    expect(screen.getByText(/1 vendor will be added to “Venue”, which has 4 vendors now/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Confirm merge" }));
    await waitFor(() =>
      expect(api.post).toHaveBeenCalledWith("/admin/category-proposals/p1/merge", { vendorCategoryId: "vc1" })
    );
  });
});
