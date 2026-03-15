/**
 * Returns the snapshot URL with an optional cache-buster.
 *
 * In production the URL is already same-origin (served by GitHub Pages),
 * so no proxy is needed. The cache-buster tells the browser to re-fetch
 * after each CI refresh cycle (~10 min).
 */
export function proxySnapshot(snapshotURL: string, cacheBust?: number): string {
  return cacheBust != null ? `${snapshotURL}?t=${cacheBust}` : snapshotURL
}
