export interface WaveCondition {
  time: Date
  waveHeight: number
  waveDirection: number
  wavePeriod: number
  swellHeight: number | null
  swellDirection: number | null
  swellPeriod: number | null
  secondarySwellHeight: number | null
  secondarySwellDirection: number | null
  secondarySwellPeriod: number | null
  windSpeed: number | null   // km/h
  windDirection: number | null // degrees
  seaSurfaceTemperature: number | null // Celsius
}
