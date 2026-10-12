export function ErrorRetry({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="page-status" role="alert">
      <p className="error-text">{message}</p>
      <button type="button" className="secondary" onClick={onRetry}>
        Try again
      </button>
    </div>
  );
}
