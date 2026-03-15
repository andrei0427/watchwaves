export interface WebcamEntry {
  id: number
  name: string
  lat: number
  lng: number
  pageURL: string
  snapshotURL: string
}

export interface WebcamPin {
  id: string
  lat: number
  lng: number
  cameras: WebcamEntry[]
}
