import { useState, useEffect, useCallback, useMemo } from 'react'
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet'
import L from 'leaflet'
import type { WaveCondition } from '../types/WaveCondition'
import type { WebcamPin, WebcamEntry } from '../types/WebcamEntry'
import { WEBCAM_PINS } from '../data/webcams'
import { MALTA_BOUNDS, MALTA_CENTER, INITIAL_ZOOM } from '../data/constants'
import { ParticleCanvas } from './ParticleCanvas'
import { LiveModal } from '../components/LiveModal'
import { heightString, windString } from '../utils/waveFormatter'
import { proxySnapshot } from '../utils/proxySnapshot'

interface Props {
  condition: WaveCondition | null
  isVisible: boolean
}

export function MapPage({ condition, isVisible }: Props) {
  const [selectedPin, setSelectedPin] = useState<WebcamPin | null>(null)
  const [liveEntry, setLiveEntry] = useState<WebcamEntry | null>(null)
  const bounds = L.latLngBounds(MALTA_BOUNDS[0], MALTA_BOUNDS[1])

  return (
    <div className="relative w-full" style={{ height: '100dvh' }}>
      <MapContainer
        center={MALTA_CENTER}
        zoom={INITIAL_ZOOM}
        style={{ width: '100%', height: '100%' }}
        maxBounds={bounds}
        maxBoundsViscosity={0.9}
        minZoom={9}
        maxZoom={16}
        zoomControl={false}
      >
        <TileLayer
          url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
          attribution='&copy; <a href="https://www.esri.com">Esri</a>'
        />
        {/* Tells Leaflet its real size whenever the tab becomes visible */}
        <MapResizer isVisible={isVisible} />
        <WebcamMarkers pins={WEBCAM_PINS} onPinClick={setSelectedPin} />
      </MapContainer>

      {/* Dark overlay — pointer-events:none so map stays interactive */}
      <div
        style={{
          position: 'absolute', inset: 0,
          background: 'rgba(0,0,0,0.28)',
          zIndex: 400, pointerEvents: 'none',
        }}
      />

      <ParticleCanvas condition={condition} />

      {condition && (
        <div
          style={{
            position: 'absolute', bottom: 76, left: '50%',
            transform: 'translateX(-50%)',
            zIndex: 500, pointerEvents: 'none',
            background: 'rgba(0,0,0,0.65)',
            backdropFilter: 'blur(6px)',
            borderRadius: 9999,
            padding: '6px 14px',
            display: 'flex', gap: 12,
            fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
          }}
        >
          <span style={{ color: 'rgb(34,211,238)' }}>〜 {heightString(condition.waveHeight)}</span>
          {condition.windSpeed != null && (
            <span style={{ color: 'rgba(255,255,255,0.8)' }}>💨 {windString(condition.windSpeed)}</span>
          )}
        </div>
      )}

      {selectedPin && (
        <WebcamSheet
          pin={selectedPin}
          onClose={() => setSelectedPin(null)}
          onWatchLive={entry => setLiveEntry(entry)}
        />
      )}

      {liveEntry && (
        <LiveModal cam={liveEntry} onClose={() => setLiveEntry(null)} />
      )}
    </div>
  )
}

// ── Map resizer ───────────────────────────────────────────────────────────────

function MapResizer({ isVisible }: { isVisible: boolean }) {
  const map = useMap()
  useEffect(() => {
    if (isVisible) {
      // rAF ensures the container has non-zero dimensions before we measure
      requestAnimationFrame(() => map.invalidateSize())
    }
  }, [isVisible, map])
  return null
}

// ── Webcam markers (declarative) ──────────────────────────────────────────────

function WebcamMarkers({
  pins,
  onPinClick,
}: {
  pins: WebcamPin[]
  onPinClick: (pin: WebcamPin) => void
}) {
  const onPinClickStable = useCallback(onPinClick, [onPinClick])

  return (
    <>
      {pins.map(pin => (
        <WebcamPinMarker key={pin.id} pin={pin} onPinClick={onPinClickStable} />
      ))}
    </>
  )
}

function WebcamPinMarker({
  pin,
  onPinClick,
}: {
  pin: WebcamPin
  onPinClick: (pin: WebcamPin) => void
}) {
  const count = pin.cameras.length

  const icon = useMemo(() => L.divIcon({
    html: `
      <div style="
        background:rgb(6,182,212);border:1.5px solid rgba(255,255,255,0.9);
        border-radius:50%;width:28px;height:28px;
        display:flex;align-items:center;justify-content:center;
        box-shadow:0 0 8px rgba(6,182,212,0.7);position:relative;
      ">
        <span style="font-size:11px;color:white;font-weight:700;line-height:1">📷</span>
        ${count > 1 ? `<span style="
          position:absolute;top:-4px;right:-4px;
          background:white;color:black;border-radius:50%;
          width:13px;height:13px;display:flex;align-items:center;justify-content:center;
          font-size:8px;font-weight:800;line-height:1;
        ">${count}</span>` : ''}
      </div>`,
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  }), [count])

  const handlers = useMemo(() => ({
    click: () => onPinClick(pin),
  }), [pin, onPinClick])

  return (
    <Marker
      position={[pin.lat, pin.lng]}
      icon={icon}
      eventHandlers={handlers}
      bubblingMouseEvents={false}
    />
  )
}

// ── Webcam popup sheet ────────────────────────────────────────────────────────

function WebcamSheet({
  pin,
  onClose,
  onWatchLive,
}: {
  pin: WebcamPin
  onClose: () => void
  onWatchLive: (entry: WebcamEntry) => void
}) {
  const [selected, setSelected] = useState(pin.cameras[0]!)

  return (
    <div
      style={{ position: 'absolute', inset: 0, zIndex: 1000 }}
      onClick={onClose}
    >
      <div
        style={{
          position: 'absolute', bottom: 72, left: 12, right: 12,
          borderRadius: 20, overflow: 'hidden',
          background: 'rgba(5,14,28,0.97)',
          backdropFilter: 'blur(12px)',
          border: '1px solid rgba(255,255,255,0.1)',
        }}
        onClick={e => e.stopPropagation()}
      >
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '12px 16px 10px',
          borderBottom: '1px solid rgba(255,255,255,0.08)',
        }}>
          <span style={{ fontSize: 14, fontWeight: 600, color: 'white' }}>{selected.name}</span>
          <button
            onClick={onClose}
            style={{ background: 'none', border: 'none', color: 'rgba(255,255,255,0.5)', fontSize: 22, cursor: 'pointer', lineHeight: 1 }}
          >×</button>
        </div>

        {pin.cameras.length > 1 && (
          <div style={{ display: 'flex', gap: 6, padding: '8px 12px 0' }}>
            {pin.cameras.map(cam => (
              <button
                key={cam.id}
                onClick={() => setSelected(cam)}
                style={{
                  fontSize: 11, fontWeight: 500,
                  padding: '4px 10px', borderRadius: 8, border: 'none', cursor: 'pointer',
                  background: selected.id === cam.id ? 'rgba(34,211,238,0.2)' : 'transparent',
                  color: selected.id === cam.id ? 'rgb(34,211,238)' : 'rgba(255,255,255,0.5)',
                }}
              >
                {cam.name.split('/').pop()?.trim().split(' ').slice(-1)[0] ?? cam.name}
              </button>
            ))}
          </div>
        )}

        <div style={{ padding: 12, paddingTop: pin.cameras.length > 1 ? 8 : 12 }}>
          <img
            key={selected.id}
            src={proxySnapshot(selected.snapshotURL, Math.floor(Date.now() / 30000))}
            alt={selected.name}
            style={{
              width: '100%', borderRadius: 14, objectFit: 'cover',
              background: 'rgba(255,255,255,0.05)',
              aspectRatio: '16/9', maxHeight: 180, display: 'block',
            }}
          />
          <button
            onClick={() => onWatchLive(selected)}
            style={{
              marginTop: 8, width: '100%', padding: '9px 0', borderRadius: 12, border: 'none',
              background: 'rgba(34,211,238,0.15)', color: 'rgb(34,211,238)',
              fontSize: 13, fontWeight: 600, cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            }}
          >
            ▶ Watch Live
          </button>
        </div>
      </div>
    </div>
  )
}
