import { compassDirection } from './compassDirection'

export function heightString(meters: number, useMetric = true): string {
  if (useMetric) return `${meters.toFixed(1)}m`
  return `${(meters * 3.28084).toFixed(0)}ft`
}

export function periodString(seconds: number): string {
  return `${Math.round(seconds)}s`
}

export function directionString(degrees: number): string {
  return compassDirection(degrees)
}

export function windString(kmh: number, useMetric = true): string {
  if (useMetric) return `${Math.round(kmh)} km/h`
  return `${Math.round(kmh * 0.621371)} mph`
}

export function temperatureString(celsius: number, useMetric = true): string {
  if (useMetric) return `${Math.round(celsius)}°C`
  return `${Math.round(celsius * 9 / 5 + 32)}°F`
}

export function relativeTimeString(date: Date): string {
  const diffMs = Date.now() - date.getTime()
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin < 1) return 'just now'
  if (diffMin < 60) return `${diffMin} min ago`
  const diffHr = Math.floor(diffMin / 60)
  if (diffHr < 24) return `${diffHr} hr ago`
  return `${Math.floor(diffHr / 24)}d ago`
}

export function inlineSummary(height: number, direction: number, period: number): string {
  return `${heightString(height)} ${directionString(direction)} ${periodString(period)}`
}
