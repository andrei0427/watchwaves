import type { WebcamEntry, WebcamPin } from '../types/WebcamEntry'

// In production (GitHub Pages) snapshots are fetched by CI with a spoofed
// Referer and bundled into the build — served same-origin, no CORS needed.
// In dev (npm run dev) they point to the CDN directly (may show "No signal"
// due to hotlink protection, which is acceptable for local development).
function snapshotSrc(id: number): string {
  if (import.meta.env.PROD) {
    return `${import.meta.env.BASE_URL}snapshots/live${id}.jpg`
  }
  return `/snapshots-proxy/live${id}.jpg`
}

function entry(id: number, name: string, lat: number, lng: number, path: string, gozo = false): WebcamEntry {
  const base = gozo
    ? `https://www.skylinewebcams.com/en/webcam/gozo/${path}.html`
    : `https://www.skylinewebcams.com/en/webcam/malta/${path}.html`
  return {
    id,
    name,
    lat,
    lng,
    pageURL: base,
    snapshotURL: snapshotSrc(id),
  }
}

export const WEBCAMS: WebcamEntry[] = [
  entry(207,  'Grand Harbour',           35.8979, 14.5125, 'malta/floriana/grand-harbour-valletta-waterfront'),
  entry(4000, 'Grand Harbour Entrance',  35.9003, 14.5069, 'malta/valletta/grand-harbour-entrance'),
  entry(257,  'Valletta Seaside',        35.8933, 14.5228, 'malta/valletta/valletta-seaside-promenade'),
  entry(213,  'Marsaxlokk',              35.8414, 14.5437, 'malta/marsaxlokk/marsaxlokk-harbour'),
  entry(261,  'Marsaxlokk Promenade',    35.8403, 14.5453, 'malta/marsaxlokk/marsaxlokk-seaside-promenade'),
  entry(214,  'Birżebbuġa / Pretty Bay', 35.8222, 14.5250, 'malta/birzebbuga/birzebbuga-beach-pretty-bay'),
  entry(5223, "St. George's Bay",        35.9206, 14.4878, 'malta/st-julians/st-george-beach'),
  entry(786,  'Golden Bay',              35.9542, 14.3328, 'malta/mellieha/golden-bay'),
  entry(755,  'Ċirkewwa Bay',            35.9853, 14.3367, 'malta/cirkewwa/cirkewwa-bay'),
  entry(754,  'Paradise Bay',            35.9878, 14.3294, 'malta/cirkewwa/paradise-bay'),
  entry(626,  "Ċirkewwa Water's Edge",   35.9858, 14.3342, 'malta/cirkewwa/cirkewwa-waters-edge'),
  entry(356,  "Sliema / St. Julian's",   35.9094, 14.5006, 'malta/sliema/sliema-waters-edge'),
  entry(4455, 'Sliema Harbour',          35.9033, 14.5072, 'malta/valletta/sliema-harbour'),
  entry(3372, "St. Paul's Bay",          35.9500, 14.3994, "malta/st-paul-s-bay/malta-st-paul-s-bay"),
  entry(5304, 'Buġibba',                 35.9511, 14.4183, 'malta/bugibba/st-pauls-bay'),
  entry(254,  'Wied iż-Żurrieq',         35.8181, 14.4492, 'malta/qrendi/wied-iz-zurrieq'),
  entry(221,  'Marsalforn Bay (Gozo)',   36.0736, 14.2544, 'marsalforn/marsalforn-bay', true),
  entry(864,  'Mġarr Harbour (Gozo)',    36.0194, 14.2983, 'mgarr/gozo-mgarr', true),
]

function cams(ids: number[]): WebcamEntry[] {
  return WEBCAMS.filter(w => ids.includes(w.id))
}

export const WEBCAM_PINS: WebcamPin[] = [
  { id: 'grand-harbour', lat: 35.8972, lng: 14.5141, cameras: cams([207, 4000, 257]) },
  { id: 'marsaxlokk',    lat: 35.8408, lng: 14.5445, cameras: cams([213, 261]) },
  { id: 'birzebbuga',    lat: 35.8222, lng: 14.5250, cameras: cams([214]) },
  { id: 'stgeorges',     lat: 35.9206, lng: 14.4878, cameras: cams([5223]) },
  { id: 'golden-bay',    lat: 35.9542, lng: 14.3328, cameras: cams([786]) },
  { id: 'cirkewwa',      lat: 35.9863, lng: 14.3334, cameras: cams([755, 754, 626]) },
  { id: 'sliema',        lat: 35.9063, lng: 14.5039, cameras: cams([356, 4455]) },
  { id: 'stpauls',       lat: 35.9506, lng: 14.4089, cameras: cams([3372, 5304]) },
  { id: 'wied',          lat: 35.8181, lng: 14.4492, cameras: cams([254]) },
  { id: 'marsalforn',    lat: 36.0736, lng: 14.2544, cameras: cams([221]) },
  { id: 'mgarr',         lat: 36.0194, lng: 14.2983, cameras: cams([864]) },
]
