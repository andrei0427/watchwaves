import type { WaveCondition } from '../types/WaveCondition'
import { groupForecast } from '../utils/groupForecast'
import { DirectionArrow } from '../components/DirectionArrow'
import { heightString, relativeTimeString } from '../utils/waveFormatter'

interface Props {
  conditions: WaveCondition[]
  isLoading: boolean
  error: string | null
  lastUpdated: Date | null
  onRefresh: () => void
}

export function ForecastPage({ conditions, isLoading, error, lastUpdated, onRefresh }: Props) {
  const groups = groupForecast(conditions)

  return (
    <div
      className="min-h-screen pb-20"
      style={{ background: 'linear-gradient(to bottom, #050e1c, #081c37)' }}
    >
      {/* Header */}
      <div className="sticky top-0 z-10 px-4 pt-6 pb-3 bg-[#050e1c]/90 backdrop-blur-sm border-b border-white/5">
        <div className="flex items-center justify-between">
          <h2 className="text-base font-bold text-white">120-Hour Forecast</h2>
          <div className="flex items-center gap-3">
            {lastUpdated && (
              <span className="text-xs text-white/40">{relativeTimeString(lastUpdated)}</span>
            )}
            <button
              onClick={onRefresh}
              disabled={isLoading}
              className="text-xs text-cyan-400/70 hover:text-cyan-400 disabled:opacity-40"
            >
              {isLoading ? '…' : 'Refresh'}
            </button>
          </div>
        </div>
      </div>

      {isLoading && groups.length === 0 && (
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-2 border-cyan-400/30 border-t-cyan-400 rounded-full animate-spin" />
        </div>
      )}

      {error && groups.length === 0 && (
        <div className="mx-4 mt-6 bg-orange-500/10 border border-orange-500/30 rounded-2xl p-4 text-center">
          <p className="text-orange-400 text-sm">⚠ {error}</p>
        </div>
      )}

      {groups.map((group, gi) => {
        // Compute period range for footer
        const periods = group.conditions.map(c => c.wavePeriod).filter(Boolean) as number[]
        const minP = Math.min(...periods)
        const maxP = Math.max(...periods)
        const periodRange = periods.length > 0
          ? minP === maxP ? `${Math.round(minP)}s` : `${Math.round(minP)}–${Math.round(maxP)}s`
          : null

        return (
          <div key={group.label} className="mt-3">
            {/* Day header */}
            <div className="px-4 py-1.5">
              <span className="text-xs font-bold text-white/60 uppercase tracking-widest">
                {group.label}
              </span>
            </div>

            {/* Column headers — only on first group */}
            {gi === 0 && (
              <div className="flex items-center px-4 pb-1 gap-2">
                <span className="w-7 shrink-0" />
                <div className="flex-1 flex items-center gap-1">
                  <span className="text-[9px] font-bold text-white/50 uppercase tracking-wide">💨 Wind</span>
                </div>
                <div className="flex-1 flex items-center gap-1">
                  <span className="text-[9px] font-bold text-cyan-400/70 uppercase tracking-wide">〜 Wave</span>
                </div>
                <div className="w-8 text-right">
                  <span className="text-[9px] font-bold text-orange-400/70 uppercase tracking-wide">°</span>
                </div>
              </div>
            )}

            {/* Rows */}
            <div className="mx-3 rounded-2xl overflow-hidden bg-white/[0.04]">
              {group.conditions.map((c, idx) => (
                <div key={c.time.toISOString()}>
                  <ForecastRow condition={c} />
                  {idx < group.conditions.length - 1 && (
                    <div className="mx-3 h-px bg-white/[0.06]" />
                  )}
                </div>
              ))}
            </div>

            {/* Footer */}
            {periodRange && (
              <div className="px-4 pt-1.5 pb-1">
                <span className="text-[10px] text-white/30">Period: {periodRange}</span>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}

function ForecastRow({ condition: c }: { condition: WaveCondition }) {
  const hour = c.time.getUTCHours()
  const hourStr = String(hour).padStart(2, '0')

  return (
    <div className="flex items-center px-3 py-2.5 gap-2">
      {/* Hour */}
      <span className="w-7 shrink-0 text-[11px] text-white/40 tabular-nums font-mono">{hourStr}</span>

      {/* Wind */}
      <div className="flex-1 flex items-center gap-1 text-[12px] text-white/80">
        {c.windSpeed != null ? (
          <>
            <span className="font-medium tabular-nums">{Math.round(c.windSpeed)}k</span>
            {c.windDirection != null && (
              <>
                <DirectionArrow degrees={c.windDirection} size={14} color="rgba(255,255,255,0.6)" />
                <span className="text-white/50 text-[10px]">
                  {compassAbbr(c.windDirection)}
                </span>
              </>
            )}
          </>
        ) : (
          <span className="text-white/20">—</span>
        )}
      </div>

      {/* Wave */}
      <div className="flex-1 flex items-center gap-1 text-[12px] text-cyan-400">
        <span className="font-semibold tabular-nums">{heightString(c.waveHeight)}</span>
        <DirectionArrow degrees={c.waveDirection} size={14} color="rgb(34,211,238)" />
        <span className="text-cyan-400/60 text-[10px]">{compassAbbr(c.waveDirection)}</span>
      </div>

      {/* Temp */}
      <div className="w-8 text-right">
        {c.seaSurfaceTemperature != null ? (
          <span className="text-[11px] text-orange-400 tabular-nums">
            {Math.round(c.seaSurfaceTemperature)}°
          </span>
        ) : (
          <span className="text-white/20 text-[11px]">—</span>
        )}
      </div>
    </div>
  )
}

function compassAbbr(deg: number): string {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
  return dirs[Math.round(((deg % 360) + 360) % 360 / 45) % 8]
}

