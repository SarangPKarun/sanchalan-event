import { Navigate, Route, Routes } from "react-router-dom";
import { LoginPage } from "./pages/LoginPage.tsx";
import { ProtectedLayout } from "./pages/ProtectedLayout.tsx";
import { VendorQueuePage } from "./pages/VendorQueuePage.tsx";
import { VendorDetailPage } from "./pages/VendorDetailPage.tsx";

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<ProtectedLayout />}>
        <Route path="/vendors" element={<VendorQueuePage />} />
        <Route path="/vendors/:id" element={<VendorDetailPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/vendors" replace />} />
    </Routes>
  );
}
