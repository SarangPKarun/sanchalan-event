/** Small in-memory sliding-window limiter. Per process, which is enough for a single API instance. */
export class RateLimiter {
  private hits = new Map<string, number[]>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number
  ) {}

  /** Returns 0 if allowed (and records the hit), otherwise the seconds until the next attempt. */
  take(key: string, now = Date.now()): number {
    const recent = (this.hits.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (recent.length >= this.max) {
      this.hits.set(key, recent);
      return Math.ceil((recent[0]! + this.windowMs - now) / 1000);
    }
    recent.push(now);
    this.hits.set(key, recent);
    if (this.hits.size > 10_000) this.sweep(now);
    return 0;
  }

  private sweep(now: number) {
    for (const [k, v] of this.hits) if (v.every((t) => now - t >= this.windowMs)) this.hits.delete(k);
  }
}
