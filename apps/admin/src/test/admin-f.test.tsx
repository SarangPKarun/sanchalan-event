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
const PAST = new Date(Date.now() - 5 * 86400000).toISOString();
const FUTURE = new Date(Date.now() + 30 * 86400000).toISOString();

const REVIEW = {
  id: "r1",
  rating: 1,
  comment: "Terrible, rude owner",
  status: "flagged",
  moderationReason: null,
  createdAt: NOW,
  vendor: { id: "v1", businessName: "Lotus Decor" },
  eventGroup: { id: "e1", name: "Riya & Arjun" },
  moderator: null,
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

describe("bookings and payments (read-only)", () => {
  it("explains the empty state while bookings are not live", async () => {
    mockApi(admin("support"), { "/admin/bookings": { bookings: [], total: 0, page: 1, pageSize: 20 } });
    renderRoutes("/bookings");
    expect(await screen.findByText(/not live in the app yet/)).toBeInTheDocument();
  });

  it("shows paid and overdue amounts for a booking", async () => {
    mockApi(admin("support"), {
      "/admin/bookings": {
        bookings: [
          {
            id: "b1", status: "confirmed", agreedPrice: "100000", createdAt: NOW,
            vendor: { id: "v1", businessName: "Lotus Decor" },
            eventGroup: { id: "e1", name: "Riya & Arjun", organizer: { id: "o1", displayName: "Sharma" } },
            payments: [],
            paymentSummary: { count: 3, paidAmount: 30000, agreedPrice: 100000, overdueCount: 1 },
          },
        ],
        total: 1, page: 1, pageSize: 20,
      },
    });
    renderRoutes("/bookings");
    expect(await screen.findByText("Lotus Decor · Riya & Arjun")).toBeInTheDocument();
    expect(screen.getByText(/₹1,00,000 agreed · ₹30,000 paid · 1 overdue/)).toBeInTheDocument();
  });

  it("labels an unpaid past-due payment as overdue and a future one as upcoming", async () => {
    const booking = { id: "b1", vendor: { id: "v1", businessName: "Lotus Decor" }, eventGroup: { id: "e1", name: "Riya & Arjun" } };
    mockApi(admin("support"), {
      "/admin/payments": {
        payments: [
          { id: "p1", milestoneType: "midpoint", amount: "40000", dueDate: PAST, paidAt: null, status: "pending", overdue: true, booking },
          { id: "p2", milestoneType: "final", amount: "30000", dueDate: FUTURE, paidAt: null, status: "pending", overdue: false, booking },
          { id: "p3", milestoneType: "advance", amount: "30000", dueDate: PAST, paidAt: PAST, status: "paid", overdue: false, booking },
        ],
        total: 3, page: 1, pageSize: 20,
      },
    });
    renderRoutes("/bookings/payments");
    await screen.findByText(/₹40,000 · midpoint/);
    expect(screen.getByText("Overdue", { selector: ".badge" })).toBeInTheDocument();
    expect(screen.getByText("Upcoming", { selector: ".badge" })).toBeInTheDocument();
    expect(screen.getByText("Paid", { selector: ".badge" })).toBeInTheDocument();
  });

  it("has no money-moving controls", async () => {
    mockApi(admin("super_admin"), { "/admin/payments": { payments: [], total: 0, page: 1, pageSize: 20 } });
    renderRoutes("/bookings/payments");
    await screen.findByText(/not live in the app yet/);
    expect(screen.queryByRole("button", { name: /refund|mark paid|pay/i })).not.toBeInTheDocument();
  });
});

describe("review moderation", () => {
  it("hides a flagged review only with a reason", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/reviews": { reviews: [REVIEW], total: 1, page: 1, pageSize: 20 } });
    renderRoutes("/reviews");
    await userEvent.click(await screen.findByRole("button", { name: "Hide" }));
    const dialog = screen.getByRole("dialog");
    const confirm = within(dialog).getByRole("button", { name: "Hide" });
    expect(confirm).toBeDisabled();
    await userEvent.type(within(dialog).getByRole("textbox"), "Abusive language");
    await userEvent.click(confirm);
    await waitFor(() => expect(api.post).toHaveBeenCalledWith("/admin/reviews/r1/hide", { reason: "Abusive language" }));
    expect(await screen.findByText("Review hidden.")).toBeInTheDocument();
  });

  it("offers Restore for a hidden review and shows why it was hidden", async () => {
    const hidden = { ...REVIEW, status: "hidden", moderationReason: "Abusive language", moderator: { name: "Seed Admin" } };
    mockApi(admin("vendor_reviewer"), { "/admin/reviews": { reviews: [hidden], total: 1, page: 1, pageSize: 20 } });
    renderRoutes("/reviews");
    expect(await screen.findByText(/hidden: Abusive language \(Seed Admin\)/)).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Restore" }));
    await userEvent.click(within(screen.getByRole("dialog")).getByRole("button", { name: "Restore" }));
    await waitFor(() => expect(api.post).toHaveBeenCalledWith("/admin/reviews/r1/restore", undefined));
  });

  it("gives support admins no moderation buttons", async () => {
    mockApi(admin("support"), { "/admin/reviews": { reviews: [REVIEW], total: 1, page: 1, pageSize: 20 } });
    renderRoutes("/reviews");
    expect(await screen.findByText("Terrible, rude owner")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Hide" })).not.toBeInTheDocument();
  });

  it("reports a lost race with the server's message", async () => {
    mockApi(admin("vendor_reviewer"), { "/admin/reviews": { reviews: [REVIEW], total: 1, page: 1, pageSize: 20 } });
    api.post.mockImplementation(async (url: string) => {
      if (url === "/auth/refresh") return { data: { accessToken: "t" } };
      throw { response: { status: 409, data: { error: "Review is already hidden" } } };
    });
    renderRoutes("/reviews");
    await userEvent.click(await screen.findByRole("button", { name: "Hide" }));
    const dialog = screen.getByRole("dialog");
    await userEvent.type(within(dialog).getByRole("textbox"), "x");
    await userEvent.click(within(dialog).getByRole("button", { name: "Hide" }));
    expect(await screen.findByText("Review is already hidden")).toBeInTheDocument();
  });
});

describe("dashboard attention cards", () => {
  it("shows overdue payments and flagged reviews only when there are some", async () => {
    const stats = (c: object) => ({
      vendors: { pending_review: 0, published: 0 }, proposals: { pending: 0 }, organizers: 0, events: 0,
      roadmaps: { lastSevenDays: 0, total: 0, failedLastSevenDays: 0, tokensLastThirtyDays: { input: 0, output: 0 } },
      oldestPending: { vendor: null, proposal: null }, commerce: c,
    });
    mockApi(admin("vendor_reviewer"), { "/admin/stats": stats({ bookings: 2, overduePayments: 1, flaggedReviews: 4 }) });
    const { unmount } = renderRoutes("/");
    expect(await screen.findByText("Overdue payments")).toBeInTheDocument();
    expect(screen.getByText("Flagged reviews").closest("a")).toHaveAttribute("href", "/reviews?status=flagged");
    unmount();
    mockApi(admin("vendor_reviewer"), { "/admin/stats": stats({ bookings: 0, overduePayments: 0, flaggedReviews: 0 }) });
    renderRoutes("/");
    await screen.findByText("Vendors awaiting review");
    expect(screen.queryByText("Overdue payments")).not.toBeInTheDocument();
  });
});
