import { useState } from 'react'
import { useMarineData } from './hooks/useMarineData'
import { TabBar, type Tab } from './components/TabBar'
import { ConditionsPage } from './conditions/ConditionsPage'
import { ForecastPage } from './forecast/ForecastPage'
import { MapPage } from './map/MapPage'
import { WebcamsPage } from './webcams/WebcamsPage'

export default function App() {
  const [tab, setTab] = useState<Tab>('waves')
  const { conditions, isLoading, error, lastUpdated, refresh } = useMarineData()

  // Find the most recent past condition (or first available)
  const now = new Date()
  const current =
    conditions.filter(c => c.time <= now).at(-1) ??
    conditions[0] ??
    null

  return (
    <div className="relative h-full" style={{ background: '#050e1c' }}>
      {/* Pages — all mounted, visibility toggled to preserve state */}
      <div className={tab === 'waves' ? 'block' : 'hidden'}>
        <ConditionsPage
          conditions={conditions}
          isLoading={isLoading}
          error={error}
          lastUpdated={lastUpdated}
          onViewForecast={() => setTab('forecast')}
          onRefresh={refresh}
        />
      </div>

      <div className={tab === 'forecast' ? 'block' : 'hidden'}>
        <ForecastPage
          conditions={conditions}
          isLoading={isLoading}
          error={error}
          lastUpdated={lastUpdated}
          onRefresh={refresh}
        />
      </div>

      {/*
        Map must never be hidden with display:none — Leaflet initialises with
        a 0×0 container and its coordinate math breaks permanently.
        Keep it always laid out; just push it behind other tabs with z-index.
      */}
      <div
        style={{
          position: tab === 'map' ? 'relative' : 'absolute',
          inset: 0,
          visibility: tab === 'map' ? 'visible' : 'hidden',
          pointerEvents: tab === 'map' ? 'auto' : 'none',
          zIndex: tab === 'map' ? 1 : 0,
        }}
      >
        <MapPage condition={current} isVisible={tab === 'map'} />
      </div>

      <div className={tab === 'webcams' ? 'block' : 'hidden'}>
        <WebcamsPage />
      </div>

      <TabBar active={tab} onSelect={setTab} />
    </div>
  )
}
