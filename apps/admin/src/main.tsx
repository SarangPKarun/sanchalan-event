import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import "./index.css";
import { App } from "./App.tsx";
import { AuthProvider } from "./lib/auth-context.tsx";
import { ToastProvider } from "./lib/toast.tsx";
import { ErrorBoundary } from "./components/ErrorBoundary.tsx";
import { VendorProvider } from "./lib/vendor-context.tsx";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ErrorBoundary>
      <BrowserRouter>
        <ToastProvider>
          <AuthProvider>
            <VendorProvider>
              <App />
            </VendorProvider>
          </AuthProvider>
        </ToastProvider>
      </BrowserRouter>
    </ErrorBoundary>
  </StrictMode>
);
