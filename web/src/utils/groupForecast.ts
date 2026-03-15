import type { WaveCondition } from '../types/WaveCondition'

export interface ForecastGroup {
  label: string
  conditions: WaveCondition[]
}

export function groupForecast(conditions: WaveCondition[]): ForecastGroup[] {
  const now = new Date()
  const cutoff = new Date(now.getTime() - 3600 * 1000)

  const groups = new Map<string, WaveCondition[]>()

  const today = toDateKey(now)
  const tomorrow = toDateKey(new Date(now.getTime() + 86400 * 1000))

  for (const c of conditions) {
    if (c.time < cutoff) continue

    const dayKey = toDateKey(c.time)
    const hour = c.time.getUTCHours()

    // Today: every hour; future: every 3 hours
    if (dayKey !== today && hour % 3 !== 0) continue

    if (!groups.has(dayKey)) groups.set(dayKey, [])
    groups.get(dayKey)!.push(c)
  }

  const result: ForecastGroup[] = []
  for (const [key, conds] of groups) {
    let label: string
    if (key === today) label = 'Today'
    else if (key === tomorrow) label = 'Tomorrow'
    else {
      // Parse yyyy-mm-dd back to date for display
      const [y, m, d] = key.split('-').map(Number)
      const date = new Date(Date.UTC(y, m - 1, d))
      label = date.toLocaleDateString('en-GB', {
        weekday: 'short',
        day: 'numeric',
        month: 'short',
        timeZone: 'UTC',
      })
    }
    result.push({ label, conditions: conds })
  }
  return result
}

function toDateKey(date: Date): string {
  // Use UTC date to stay consistent with API timestamps (GMT)
  const y = date.getUTCFullYear()
  const m = String(date.getUTCMonth() + 1).padStart(2, '0')
  const d = String(date.getUTCDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}
