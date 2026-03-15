export interface MarineAPIResponse {
  latitude: number
  longitude: number
  hourly?: MarineHourlyData
}

export interface MarineHourlyData {
  time: string[]
  wave_height?: (number | null)[]
  wave_direction?: (number | null)[]
  wave_period?: (number | null)[]
  swell_wave_height?: (number | null)[]
  swell_wave_direction?: (number | null)[]
  swell_wave_period?: (number | null)[]
  secondary_swell_wave_height?: (number | null)[]
  secondary_swell_wave_direction?: (number | null)[]
  secondary_swell_wave_period?: (number | null)[]
  sea_surface_temperature?: (number | null)[]
}

export interface WeatherAPIResponse {
  latitude: number
  longitude: number
  hourly?: WeatherHourlyData
}

export interface WeatherHourlyData {
  time: string[]
  wind_speed_10m?: (number | null)[]
  wind_direction_10m?: (number | null)[]
}
