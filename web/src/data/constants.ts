// Ocean point used for marine API query (open Mediterranean off Malta)
export const OCEAN_POINT = { lat: 35.9, lng: 14.2 }

// Wind query point (over Malta land mass for better wind model)
export const WIND_POINT = { lat: 35.9, lng: 14.4 }

// Map bounds — constrains Leaflet camera to Malta + Gozo area
export const MALTA_BOUNDS: [[number, number], [number, number]] = [
  [35.75, 14.1],  // SW corner
  [36.15, 14.65], // NE corner
]

// Initial map center
export const MALTA_CENTER: [number, number] = [35.92, 14.4]

// Initial zoom level
export const INITIAL_ZOOM = 11

// API forecast hours
export const FORECAST_HOURS = 120

// Cache duration in milliseconds (5 minutes)
export const CACHE_TTL_MS = 5 * 60 * 1000

// Webcam snapshot refresh interval.
// In production snapshots are served from GitHub Pages and refreshed by CI
// every 10 minutes, so polling faster than that just re-fetches the same file.
export const WEBCAM_REFRESH_MS = import.meta.env.PROD ? 10 * 60 * 1000 : 30 * 1000
