import { useEffect, useRef } from 'react'
import type { WaveCondition } from '../types/WaveCondition'

interface Props {
  condition: WaveCondition | null
}

// Reduced counts match watchOS (120/80) — map is small anyway
const WAVE_COUNT = 100
const WIND_COUNT = 70
const TARGET_FPS = 30
const FRAME_MS = 1000 / TARGET_FPS

export function ParticleCanvas({ condition }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const rafRef = useRef<number>(0)
  const conditionRef = useRef(condition)
  conditionRef.current = condition

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let startTime: number | null = null
    let lastFrameTime = 0

    function resize() {
      if (!canvas) return
      const dpr = window.devicePixelRatio || 1
      canvas.width = canvas.offsetWidth * dpr
      canvas.height = canvas.offsetHeight * dpr
      ctx!.setTransform(dpr, 0, 0, dpr, 0, 0)
    }

    const ro = new ResizeObserver(resize)
    ro.observe(canvas)
    resize()

    function draw(timestamp: number) {
      rafRef.current = requestAnimationFrame(draw)

      // Pause when tab is hidden
      if (document.hidden) return
      // Throttle to TARGET_FPS
      if (timestamp - lastFrameTime < FRAME_MS) return
      lastFrameTime = timestamp

      if (!canvas || !ctx) return
      if (startTime === null) startTime = timestamp
      const time = (timestamp - startTime) / 1000

      const w = canvas.offsetWidth
      const h = canvas.offsetHeight
      ctx.clearRect(0, 0, w, h)

      const c = conditionRef.current
      if (!c) return

      const cx = w / 2
      const cy = h / 2
      const canvasRadius = Math.hypot(w, h) / 2

      drawWaveParticles(ctx, cx, cy, canvasRadius, w, h, time, c)
      drawWindParticles(ctx, cx, cy, canvasRadius, w, h, time, c)
    }

    rafRef.current = requestAnimationFrame(draw)
    return () => cancelAnimationFrame(rafRef.current)
  }, []) // stable — reads condition via ref

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'absolute', inset: 0,
        width: '100%', height: '100%',
        pointerEvents: 'none', zIndex: 410,
      }}
    />
  )
}

function drawWaveParticles(
  ctx: CanvasRenderingContext2D,
  cx: number, cy: number, canvasRadius: number,
  w: number, h: number, time: number,
  c: WaveCondition,
) {
  const height = Math.min(c.waveHeight, 5.0)
  const period = Math.max(c.wavePeriod, 3.0)
  const speed = 1.0 / period
  const baseOpacity = 0.4 + (height / 5.0) * 0.4
  const scale = 4.0 + height

  const dirRad = (c.waveDirection + 180 - 90) * Math.PI / 180
  const perpRad = dirRad + Math.PI / 2
  const cosDr = Math.cos(dirRad), sinDr = Math.sin(dirRad)
  const cosPr = Math.cos(perpRad), sinPr = Math.sin(perpRad)
  const dx = cosDr * scale, dy = sinDr * scale
  const nx = cosPr * scale * 0.4, ny = sinPr * scale * 0.4

  // Place particles into a coarse grid to avoid O(n²) check
  const cellSize = 16
  const cols = Math.ceil(w / cellSize) + 1
  const occupied = new Uint8Array((Math.ceil(h / cellSize) + 1) * cols)

  ctx.lineWidth = 1.8

  for (let i = 0; i < WAVE_COUNT; i++) {
    const seed = i * 137.508
    let phase = (seed / 360.0 + time * speed * 0.4) % 1.0
    if (phase < 0) phase += 1

    const spreadFactor = (i % 17 - 8) / 8.0
    const driftOffset = (i % 7 - 3) / 3.0 * 5.0
    const travelDist = (phase - 0.5) * canvasRadius * 2.6
    const spreadDist = spreadFactor * canvasRadius * 0.9

    const x = cx + cosDr * travelDist + cosPr * (spreadDist + driftOffset)
    const y = cy + sinDr * travelDist + sinPr * (spreadDist + driftOffset)

    if (x < -10 || x > w + 10 || y < -10 || y > h + 10) continue

    const col = Math.floor(x / cellSize)
    const row = Math.floor(y / cellSize)
    const cell = row * cols + col
    if (occupied[cell]) continue
    occupied[cell] = 1

    const distFromEdge = Math.min(x, y, w - x, h - y)
    const opacity = baseOpacity * Math.min(distFromEdge / 20.0, 1.0)

    ctx.beginPath()
    ctx.moveTo(x - dx, y - dy)
    ctx.quadraticCurveTo(x - dx * 0.5 + nx, y - dy * 0.5 + ny, x, y)
    ctx.quadraticCurveTo(x + dx * 0.5 - nx, y + dy * 0.5 - ny, x + dx, y + dy)
    ctx.strokeStyle = `rgba(34,211,238,${opacity.toFixed(2)})`
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(x + dx, y + dy, 1.25, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(34,211,238,${Math.min(opacity * 1.2, 1).toFixed(2)})`
    ctx.fill()
  }
}

function drawWindParticles(
  ctx: CanvasRenderingContext2D,
  cx: number, cy: number, canvasRadius: number,
  w: number, h: number, time: number,
  c: WaveCondition,
) {
  if (c.windDirection == null || c.windSpeed == null) return

  const normalizedSpeed = Math.min(c.windSpeed / 50.0, 1.0)
  const baseOpacity = 0.2 + normalizedSpeed * 0.35
  const speed = 0.15 + normalizedSpeed * 0.25
  const streakLength = 5.0 + normalizedSpeed * 6.0

  const dirRad = (c.windDirection + 180 - 90) * Math.PI / 180
  const perpRad = dirRad + Math.PI / 2
  const cosDr = Math.cos(dirRad), sinDr = Math.sin(dirRad)
  const cosPr = Math.cos(perpRad), sinPr = Math.sin(perpRad)
  const dx = cosDr * streakLength, dy = sinDr * streakLength

  const cellSize = 14
  const cols = Math.ceil(w / cellSize) + 1
  const occupied = new Uint8Array((Math.ceil(h / cellSize) + 1) * cols)

  ctx.lineWidth = 1.2

  for (let i = 0; i < WIND_COUNT; i++) {
    const seed = i * 97.135 + 50
    let phase = (seed / 360.0 + time * speed) % 1.0
    if (phase < 0) phase += 1

    const spreadFactor = (i % 13 - 6) / 6.0
    const driftOffset = (i % 5 - 2) / 2.0 * 4.0
    const travelDist = (phase - 0.5) * canvasRadius * 2.6
    const spreadDist = spreadFactor * canvasRadius * 0.9

    const x = cx + cosDr * travelDist + cosPr * (spreadDist + driftOffset)
    const y = cy + sinDr * travelDist + sinPr * (spreadDist + driftOffset)

    if (x < -10 || x > w + 10 || y < -10 || y > h + 10) continue

    const col = Math.floor(x / cellSize)
    const row = Math.floor(y / cellSize)
    const cell = row * cols + col
    if (occupied[cell]) continue
    occupied[cell] = 1

    const distFromEdge = Math.min(x, y, w - x, h - y)
    const opacity = baseOpacity * Math.min(distFromEdge / 20.0, 1.0)

    ctx.beginPath()
    ctx.moveTo(x - dx, y - dy)
    ctx.lineTo(x + dx, y + dy)
    ctx.strokeStyle = `rgba(255,255,255,${(opacity * 0.7).toFixed(2)})`
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(x + dx, y + dy, 1.0, 0, Math.PI * 2)
    ctx.fillStyle = `rgba(255,255,255,${Math.min(opacity * 1.2, 1).toFixed(2)})`
    ctx.fill()
  }
}
