import { Route, Routes } from "react-router-dom";
import { LoginPage } from "./pages/LoginPage.tsx";
import { Layout } from "./components/Layout.tsx";
import { AccountPage } from "./pages/AccountPage.tsx";
import { TeamPage } from "./pages/TeamPage.tsx";
import { DashboardPage } from "./pages/DashboardPage.tsx";
import { FamiliesPage } from "./pages/FamiliesPage.tsx";
import { FamilyDetailPage } from "./pages/FamilyDetailPage.tsx";
import { EventsPage } from "./pages/EventsPage.tsx";
import { EventDetailPage } from "./pages/EventDetailPage.tsx";
import { RoadmapPage } from "./pages/RoadmapPage.tsx";
import { RoadmapLogPage } from "./pages/RoadmapLogPage.tsx";
import { TemplateFeedbackPage } from "./pages/TemplateFeedbackPage.tsx";
import { AuditPage } from "./pages/AuditPage.tsx";
import { BookingsPage } from "./pages/BookingsPage.tsx";
import { BookingDetailPage } from "./pages/BookingDetailPage.tsx";
import { PaymentsPage } from "./pages/PaymentsPage.tsx";
import { ReviewsPage } from "./pages/ReviewsPage.tsx";
import { NotFoundPage } from "./pages/NotFoundPage.tsx";
import { VendorQueuePage } from "./pages/VendorQueuePage.tsx";
import { VendorDetailPage } from "./pages/VendorDetailPage.tsx";
import { CategoriesPage } from "./pages/CategoriesPage.tsx";
import { CategoryDetailPage } from "./pages/CategoryDetailPage.tsx";
import { CategoryProposalsPage } from "./pages/CategoryProposalsPage.tsx";

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<Layout />}>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/vendors" element={<VendorQueuePage />} />
        <Route path="/families" element={<FamiliesPage />} />
        <Route path="/families/:id" element={<FamilyDetailPage />} />
        <Route path="/events" element={<EventsPage />} />
        <Route path="/events/:id" element={<EventDetailPage />} />
        <Route path="/roadmap" element={<RoadmapPage />} />
        <Route path="/roadmap/feedback" element={<TemplateFeedbackPage />} />
        <Route path="/roadmap/:id" element={<RoadmapLogPage />} />
        <Route path="/bookings" element={<BookingsPage />} />
        <Route path="/bookings/payments" element={<PaymentsPage />} />
        <Route path="/bookings/:id" element={<BookingDetailPage />} />
        <Route path="/reviews" element={<ReviewsPage />} />
        <Route path="/audit" element={<AuditPage />} />
        <Route path="/categories" element={<CategoriesPage />} />
        <Route path="/categories/proposals" element={<CategoryProposalsPage />} />
        <Route path="/categories/:key" element={<CategoryDetailPage />} />
        <Route path="/vendors/:id" element={<VendorDetailPage />} />
        <Route path="/account" element={<AccountPage />} />
        <Route path="/team" element={<TeamPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
    </Routes>
  );
}
