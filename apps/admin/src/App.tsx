import { Navigate, Route, Routes } from "react-router-dom";
import { LoginPage } from "./pages/LoginPage.tsx";
import { Layout } from "./components/Layout.tsx";
import { AccountPage } from "./pages/AccountPage.tsx";
import { TeamPage } from "./pages/TeamPage.tsx";
import { NotFoundPage } from "./pages/NotFoundPage.tsx";
import { VendorQueuePage } from "./pages/VendorQueuePage.tsx";
import { VendorDetailPage } from "./pages/VendorDetailPage.tsx";
import { CategoryProposalsPage } from "./pages/CategoryProposalsPage.tsx";

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<Layout />}>
        <Route path="/vendors" element={<VendorQueuePage />} />
        <Route path="/categories" element={<CategoryProposalsPage />} />
        <Route path="/vendors/:id" element={<VendorDetailPage />} />
        <Route path="/account" element={<AccountPage />} />
        <Route path="/team" element={<TeamPage />} />
        <Route path="*" element={<NotFoundPage />} />
      </Route>
      <Route path="/" element={<Navigate to="/vendors" replace />} />
    </Routes>
  );
}
