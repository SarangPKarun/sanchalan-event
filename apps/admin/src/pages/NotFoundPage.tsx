import { Link } from "react-router-dom";
import { usePageTitle } from "../components/usePageTitle.ts";

export function NotFoundPage() {
  usePageTitle("Not found");
  return (
    <div className="page">
      <h1>Page not found</h1>
      <p>
        <Link to="/">Back to the dashboard</Link>
      </p>
    </div>
  );
}
