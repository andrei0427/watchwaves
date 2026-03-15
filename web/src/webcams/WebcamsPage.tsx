import { useState, useEffect } from 'react'
import { WEBCAMS } from '../data/webcams'
import type { WebcamEntry } from '../types/WebcamEntry'
import { WEBCAM_REFRESH_MS } from '../data/constants'
import { LiveModal } from '../components/LiveModal'
import { proxySnapshot } from '../utils/proxySnapshot'

export function WebcamsPage() {
  const [cacheBust, setCacheBust] = useState(() => Math.floor(Date.now() / WEBCAM_REFRESH_MS))
  const [liveEntry, setLiveEntry] = useState<WebcamEntry | null>(null)

  useEffect(() => {
    const id = setInterval(
      () => setCacheBust(Math.floor(Date.now() / WEBCAM_REFRESH_MS)),
      WEBCAM_REFRESH_MS,
    )
    return () => clearInterval(id)
  }, [])

  const sorted = [...WEBCAMS].sort((a, b) => a.name.localeCompare(b.name))

  return (
    <>
      <div
        className="min-h-screen pb-20"
        style={{ background: 'linear-gradient(to bottom, #050e1c, #081c37)' }}
      >
        <div className="sticky top-0 z-10 px-4 pt-6 pb-3 bg-[#050e1c]/90 backdrop-blur-sm border-b border-white/5">
          <h2 className="text-base font-bold text-white">Webcams</h2>
          <p className="text-xs text-white/40 mt-0.5">18 coastal cameras · snapshots refresh every 30s</p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3">
          {sorted.map(cam => (
            <WebcamCard
              key={cam.id}
              cam={cam}
              cacheBust={cacheBust}
              onWatchLive={() => setLiveEntry(cam)}
            />
          ))}
        </div>
      </div>

      {liveEntry && (
        <LiveModal cam={liveEntry} onClose={() => setLiveEntry(null)} />
      )}
    </>
  )
}

function WebcamCard({
  cam,
  cacheBust,
  onWatchLive,
}: {
  cam: WebcamEntry
  cacheBust: number
  onWatchLive: () => void
}) {
  const [hasError, setHasError] = useState(false)

  useEffect(() => { setHasError(false) }, [cacheBust])

  return (
    <div className="rounded-2xl overflow-hidden bg-white/[0.05] border border-white/[0.07]">
      {/* Snapshot — clicking it also opens the live stream */}
      <button
        onClick={onWatchLive}
        className="relative w-full bg-white/5 block"
        style={{ aspectRatio: '16/9' }}
      >
        {hasError ? (
          <div className="absolute inset-0 flex items-center justify-center text-white/20 text-sm">
            No signal
          </div>
        ) : (
          <img
            src={proxySnapshot(cam.snapshotURL, cacheBust)}
            alt={cam.name}
            className="w-full h-full object-cover"
            onError={() => setHasError(true)}
            loading="lazy"
          />
        )}
        {/* Play overlay */}
        <div className="absolute inset-0 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity"
          style={{ background: 'rgba(0,0,0,0.35)' }}>
          <span className="text-3xl">▶</span>
        </div>
      </button>

      {/* Info row */}
      <div className="flex items-center justify-between px-3 py-2.5">
        <p className="text-sm font-semibold text-white leading-tight truncate mr-2">{cam.name}</p>
        <button
          onClick={onWatchLive}
          className="shrink-0 px-3 py-1.5 rounded-lg bg-cyan-400/15 text-cyan-400 text-xs font-medium hover:bg-cyan-400/25 transition-colors"
        >
          ▶ Live
        </button>
      </div>
    </div>
  )
}
