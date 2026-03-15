import type { WaveCondition } from '../types/WaveCondition'
import { DirectionArrow } from '../components/DirectionArrow'
import {
  heightString,
  periodString,
  directionString,
  windString,
  temperatureString,
  relativeTimeString,
} from '../utils/waveFormatter'

interface Props {
  conditions: WaveCondition[]
  isLoading: boolean
  error: string | null
  lastUpdated: Date | null
  onViewForecast: () => void
  onRefresh: () => void
}

export function ConditionsPage({ conditions, isLoading, error, lastUpdated, onViewForecast, onRefresh }: Props) {
  const now = conditions.find(c => c.time <= new Date()) ?? conditions[0]

  return (
    <div
      className="min-h-screen pb-20 px-4 pt-6"
      style={{
        background: 'linear-gradient(to bottom, #050e1c, #081c37)',
      }}
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div>
          <h1 className="text-lg font-bold text-white">WatchWaves</h1>
          <p className="text-xs text-white/50">Malta Marine Conditions</p>
        </div>
        {lastUpdated && (
          <p className="text-xs text-white/40">{relativeTimeString(lastUpdated)}</p>
        )}
      </div>

      {isLoading && !now && (
        <div className="flex flex-col items-center justify-center gap-3 py-20">
          <div className="w-8 h-8 border-2 border-cyan-400/30 border-t-cyan-400 rounded-full animate-spin" />
          <p className="text-white/50 text-sm">Loading conditions…</p>
        </div>
      )}

      {error && !now && (
        <div className="bg-orange-500/10 border border-orange-500/30 rounded-2xl p-4 text-center">
          <p className="text-orange-400 text-sm font-medium">⚠ {error}</p>
          <button
            onClick={onRefresh}
            className="mt-3 text-xs text-white/60 underline"
          >
            Retry
          </button>
        </div>
      )}

      {now && (
        <div className="flex flex-col gap-3 max-w-md mx-auto">
          {/* Wave Hero Card */}
          <div
            className="rounded-2xl p-6 border"
            style={{
              background: 'rgba(6, 182, 212, 0.12)',
              borderColor: 'rgba(6, 182, 212, 0.25)',
            }}
          >
            <div className="flex items-start justify-between">
              <div>
                <div className="flex items-baseline gap-2">
                  <span className="text-[72px] font-bold leading-none text-white tabular-nums">
                    {now.waveHeight.toFixed(1)}
                  </span>
                  <span className="text-2xl text-white/70 font-medium">m</span>
                </div>
                <div className="flex items-center gap-2 mt-2 text-white/70">
                  <DirectionArrow degrees={now.waveDirection} size={18} color="rgb(34,211,238)" />
                  <span className="text-sm">{directionString(now.waveDirection)}</span>
                  <span className="text-white/40">·</span>
                  <span className="text-sm">{periodString(now.wavePeriod)}</span>
                </div>
              </div>
              {now.seaSurfaceTemperature != null && (
                <div className="flex flex-col items-end">
                  <span className="text-orange-400 text-sm font-semibold">
                    {temperatureString(now.seaSurfaceTemperature)}
                  </span>
                  <span className="text-white/40 text-xs">sea temp</span>
                </div>
              )}
            </div>
          </div>

          {/* Wind Card */}
          {now.windSpeed != null && now.windDirection != null && (
            <div className="rounded-2xl p-4 bg-white/[0.07]">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 flex items-center justify-center rounded-full bg-white/10">
                    <span className="text-sm">💨</span>
                  </div>
                  <div>
                    <p className="text-xs text-white/50 uppercase tracking-wide font-medium">Wind</p>
                    <p className="text-white font-semibold">{windString(now.windSpeed)}</p>
                  </div>
                </div>
                <div className="flex items-center gap-1 text-white/60 text-sm">
                  <DirectionArrow degrees={now.windDirection} size={22} color="rgba(255,255,255,0.7)" />
                  <span>{directionString(now.windDirection)}</span>
                </div>
              </div>
            </div>
          )}

          {/* Primary Swell Card */}
          {now.swellHeight != null && now.swellHeight > 0.05 && (
            <SwellCard
              label="Primary Swell"
              height={now.swellHeight}
              direction={now.swellDirection}
              period={now.swellPeriod}
            />
          )}

          {/* Secondary Swell Card */}
          {now.secondarySwellHeight != null && now.secondarySwellHeight > 0.1 && (
            <SwellCard
              label="Secondary Swell"
              height={now.secondarySwellHeight}
              direction={now.secondarySwellDirection}
              period={now.secondarySwellPeriod}
            />
          )}

          {/* Forecast Button */}
          <button
            onClick={onViewForecast}
            className="rounded-2xl p-4 bg-white/[0.07] flex items-center justify-between w-full hover:bg-white/10 transition-colors"
          >
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 flex items-center justify-center rounded-full bg-white/10">
                <span className="text-sm">📅</span>
              </div>
              <div className="text-left">
                <p className="text-xs text-white/50 uppercase tracking-wide font-medium">Forecast</p>
                <p className="text-white font-semibold">120-hour forecast</p>
              </div>
            </div>
            <span className="text-white/40 text-lg">›</span>
          </button>

          {/* Refresh */}
          <button
            onClick={onRefresh}
            disabled={isLoading}
            className="text-xs text-white/30 py-2 hover:text-white/50 transition-colors disabled:opacity-40"
          >
            {isLoading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      )}
    </div>
  )
}

interface SwellCardProps {
  label: string
  height: number
  direction: number | null
  period: number | null
}

function SwellCard({ label, height, direction, period }: SwellCardProps) {
  return (
    <div className="rounded-2xl p-4 bg-white/[0.07]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 flex items-center justify-center rounded-full bg-cyan-400/10">
            <span className="text-cyan-400 text-sm">〜</span>
          </div>
          <div>
            <p className="text-xs text-white/50 uppercase tracking-wide font-medium">{label}</p>
            <p className="text-cyan-400 font-semibold">{heightString(height)}</p>
          </div>
        </div>
        <div className="text-right text-sm text-white/60">
          {direction != null && (
            <div className="flex items-center gap-1 justify-end">
              <DirectionArrow degrees={direction} size={16} color="rgba(255,255,255,0.5)" />
              <span>{directionString(direction)}</span>
            </div>
          )}
          {period != null && <p className="text-xs mt-0.5">{periodString(period)}</p>}
        </div>
      </div>
    </div>
  )
}
