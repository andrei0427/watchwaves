import type { MarineAPIResponse, WeatherAPIResponse } from '../types/MarineApiResponse'
import type { WaveCondition } from '../types/WaveCondition'
import { OCEAN_POINT, WIND_POINT, FORECAST_HOURS } from '../data/constants'

const MARINE_BASE = 'https://marine-api.open-meteo.com/v1/marine'
const WEATHER_BASE = 'https://api.open-meteo.com/v1/forecast'

async function fetchMarine(): Promise<MarineAPIResponse> {
  const params = new URLSearchParams({
    latitude: OCEAN_POINT.lat.toFixed(4),
    longitude: OCEAN_POINT.lng.toFixed(4),
    hourly: [
      'wave_height', 'wave_direction', 'wave_period',
      'swell_wave_height', 'swell_wave_direction', 'swell_wave_period',
      'secondary_swell_wave_height', 'secondary_swell_wave_direction', 'secondary_swell_wave_period',
      'sea_surface_temperature',
    ].join(','),
    forecast_hours: String(FORECAST_HOURS),
  })
  const res = await fetch(`${MARINE_BASE}?${params}`)
  if (!res.ok) throw new Error(`Marine API error ${res.status}`)
  return res.json() as Promise<MarineAPIResponse>
}

async function fetchWind(): Promise<WeatherAPIResponse> {
  const params = new URLSearchParams({
    latitude: WIND_POINT.lat.toFixed(4),
    longitude: WIND_POINT.lng.toFixed(4),
    hourly: 'wind_speed_10m,wind_direction_10m',
    forecast_hours: String(FORECAST_HOURS),
    models: 'ecmwf_ifs025',
  })
  const res = await fetch(`${WEATHER_BASE}?${params}`)
  if (!res.ok) throw new Error(`Wind API error ${res.status}`)
  return res.json() as Promise<WeatherAPIResponse>
}

function parseConditions(marine: MarineAPIResponse, weather: WeatherAPIResponse | null): WaveCondition[] {
  const hourly = marine.hourly
  if (!hourly) return []

  // Build wind lookup by timestamp string
  const windByTime = new Map<string, { speed: number | null; dir: number | null }>()
  if (weather?.hourly) {
    const wh = weather.hourly
    for (let i = 0; i < wh.time.length; i++) {
      windByTime.set(wh.time[i], {
        speed: wh.wind_speed_10m?.[i] ?? null,
        dir: wh.wind_direction_10m?.[i] ?? null,
      })
    }
  }

  const conditions: WaveCondition[] = []

  for (let i = 0; i < hourly.time.length; i++) {
    // Parse ISO 8601 date (yyyy-MM-ddTHH:mm in GMT)
    const timeStr = hourly.time[i]
    const date = new Date(timeStr + ':00Z')
    if (isNaN(date.getTime())) continue

    const h = hourly.wave_height?.[i]
    const d = hourly.wave_direction?.[i]
    const p = hourly.wave_period?.[i]

    if (h == null || d == null || p == null) continue

    const wind = windByTime.get(timeStr)

    conditions.push({
      time: date,
      waveHeight: h,
      waveDirection: d,
      wavePeriod: p,
      swellHeight: hourly.swell_wave_height?.[i] ?? null,
      swellDirection: hourly.swell_wave_direction?.[i] ?? null,
      swellPeriod: hourly.swell_wave_period?.[i] ?? null,
      secondarySwellHeight: hourly.secondary_swell_wave_height?.[i] ?? null,
      secondarySwellDirection: hourly.secondary_swell_wave_direction?.[i] ?? null,
      secondarySwellPeriod: hourly.secondary_swell_wave_period?.[i] ?? null,
      windSpeed: wind?.speed ?? null,
      windDirection: wind?.dir ?? null,
      seaSurfaceTemperature: hourly.sea_surface_temperature?.[i] ?? null,
    })
  }

  return conditions
}

export async function fetchMarineData(): Promise<WaveCondition[]> {
  const [marine, wind] = await Promise.all([
    fetchMarine(),
    fetchWind().catch(() => null),
  ])
  return parseConditions(marine, wind)
}
