import { Component, type ReactNode } from "react";

export class ErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div className="centered-page">
        <div className="card">
          <h1>Something went wrong</h1>
          <p>The page hit an unexpected error.</p>
          <button type="button" onClick={() => window.location.assign("/")}>
            Reload
          </button>
        </div>
      </div>
    );
  }
}
