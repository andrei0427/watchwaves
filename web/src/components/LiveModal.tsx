import { useState, useEffect, useRef } from 'react'
import type { WebcamEntry } from '../types/WebcamEntry'
import { proxySnapshot } from '../utils/proxySnapshot'

interface Props {
  cam: WebcamEntry
  onClose: () => void
}

type State =
  | { status: 'resolving' }
  | { status: 'playing'; streamURL: string }
  | { status: 'snapshot' }  // proxies reachable but no token in page HTML

// Tried in order until one succeeds
const CORS_PROXIES = [
  (url: string) => `https://corsproxy.io/?${encodeURIComponent(url)}`,
  (url: string) => `https://api.allorigins.win/raw?url=${encodeURIComponent(url)}`,
]

function extractToken(html: string): string | null {
  // Pattern 1: livee.m3u8?a=TOKEN or live.m3u8?a=TOKEN
  const m1 = html.match(/live[e]?\.m3u8\?a=([a-z0-9]+)/)
  if (m1) return `https://hd-auth.skylinewebcams.com/live.m3u8?a=${m1[1]}`
  // Pattern 2: full absolute URL
  const m2 = html.match(/https:\/\/hd-auth\.skylinewebcams\.com\/live[e]?\.m3u8\?a=[a-z0-9]+/)
  if (m2) return m2[0]
  return null
}

// Returns stream URL if found, null if page was reachable but had no token.
// Throws only if every proxy failed (network error / non-ok response).
async function resolveStreamURL(pageURL: string): Promise<string | null> {
  let lastErr: unknown
  for (const makeProxy of CORS_PROXIES) {
    try {
      const res = await fetch(makeProxy(pageURL), { signal: AbortSignal.timeout(8000) })
      if (!res.ok) continue
      const html = await res.text()
      const token = extractToken(html)
      if (token) return token
      return null  // page fetched successfully, no token → camera may not have live stream
    } catch (e) {
      lastErr = e
    }
  }
  throw lastErr
}

export function LiveModal({ cam, onClose }: Props) {
  const [state, setState] = useState<State>({ status: 'resolving' })
  const [needsTap, setNeedsTap] = useState(false)
  const videoRef = useRef<HTMLVideoElement>(null)
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const hlsRef = useRef<any>(null)

  // Lock body scroll
  useEffect(() => {
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = '' }
  }, [])

  // Escape key
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])

  // Resolve stream token — any failure falls back to snapshot view
  useEffect(() => {
    let cancelled = false
    resolveStreamURL(cam.pageURL)
      .then(url => {
        if (cancelled) return
        setState(url ? { status: 'playing', streamURL: url } : { status: 'snapshot' })
      })
      .catch(() => {
        if (!cancelled) setState({ status: 'snapshot' })
      })
    return () => { cancelled = true }
  }, [cam.pageURL])

  // Attach HLS when we have a stream URL — lazy-import hls.js
  useEffect(() => {
    if (state.status !== 'playing') return
    const video = videoRef.current
    if (!video) return

    const src = state.streamURL
    let cancelled = false

    // Safari supports HLS natively — no hls.js needed
    if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = src
      video.play().catch(() => setNeedsTap(true))
      return
    }

    // Other browsers: lazy-load hls.js
    import('hls.js').then(({ default: Hls }) => {
      if (cancelled || !video) return
      if (!Hls.isSupported()) return
      const hls = new Hls()
      hlsRef.current = hls
      hls.loadSource(src)
      hls.attachMedia(video)
      hls.on(Hls.Events.MANIFEST_PARSED, () => { void video.play() })
    })

    return () => {
      cancelled = true
      hlsRef.current?.destroy()
      hlsRef.current = null
    }
  }, [state])

  const isLive = state.status === 'playing'

  return (
    <div
      className="fixed inset-0 flex flex-col"
      style={{ zIndex: 2000, background: '#000' }}
    >
      {/* Top bar */}
      <div
        className="flex items-center justify-between px-4 py-3 shrink-0"
        style={{ background: 'rgba(5,14,28,0.95)', borderBottom: '1px solid rgba(255,255,255,0.07)' }}
      >
        <div className="flex items-center gap-2">
          {isLive && (
            <span className="flex items-center gap-1.5 px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 text-[10px] font-bold uppercase tracking-wide">
              <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse inline-block" />
              Live
            </span>
          )}
          <span className="text-sm font-semibold text-white truncate max-w-[220px]">{cam.name}</span>
        </div>
        <button
          onClick={onClose}
          className="text-white/50 hover:text-white text-2xl leading-none ml-4"
          aria-label="Close"
        >×</button>
      </div>

      {/* Content */}
      <div className="flex-1 relative overflow-hidden flex items-center justify-center bg-black">
        {state.status === 'resolving' && (
          <div className="flex flex-col items-center gap-3 text-white/50">
            <div className="w-8 h-8 border-2 border-cyan-400/30 border-t-cyan-400 rounded-full animate-spin" />
            <span className="text-sm">Connecting to live stream…</span>
          </div>
        )}

        {state.status === 'playing' && (
          <div className="relative w-full h-full flex items-center justify-center">
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              controls
              className="w-full h-full object-contain"
            />
            {needsTap && (
              <button
                className="absolute inset-0 flex items-center justify-center"
                onClick={() => { videoRef.current?.play().catch(() => {}); setNeedsTap(false) }}
              >
                <div className="flex flex-col items-center gap-2">
                  <div className="w-16 h-16 rounded-full bg-white/20 flex items-center justify-center backdrop-blur-sm">
                    <span className="text-white text-3xl pl-1">▶</span>
                  </div>
                  <span className="text-white/70 text-sm">Tap to play</span>
                </div>
              </button>
            )}
          </div>
        )}

        {state.status === 'snapshot' && (
          <div className="flex flex-col items-center gap-4 p-6 text-center max-w-xs">
            <img
              src={proxySnapshot(cam.snapshotURL, Math.floor(Date.now() / 30000))}
              alt={cam.name}
              className="w-full rounded-2xl object-cover"
              style={{ aspectRatio: '16/9' }}
            />
            <p className="text-white/50 text-sm">Live stream unavailable — showing latest snapshot.</p>
            <a
              href={cam.pageURL}
              target="_blank"
              rel="noopener noreferrer"
              className="px-5 py-2 rounded-xl bg-cyan-400/15 text-cyan-400 text-sm font-medium hover:bg-cyan-400/25 transition-colors"
            >
              Watch on Skyline Webcams ↗
            </a>
          </div>
        )}
      </div>
    </div>
  )
}
