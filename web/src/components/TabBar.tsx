export type Tab = 'waves' | 'forecast' | 'map' | 'webcams'

interface Props {
  active: Tab
  onSelect: (tab: Tab) => void
}

const TABS: { id: Tab; label: string; icon: string }[] = [
  { id: 'waves', label: 'Waves', icon: '〜' },
  { id: 'forecast', label: 'Forecast', icon: '📅' },
  { id: 'map', label: 'Map', icon: '🗺' },
  { id: 'webcams', label: 'Webcams', icon: '📷' },
]

export function TabBar({ active, onSelect }: Props) {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-[#050e1c]/95 backdrop-blur-sm border-t border-white/10">
      <div className="flex">
        {TABS.map(tab => (
          <button
            key={tab.id}
            onClick={() => onSelect(tab.id)}
            className={`flex-1 flex flex-col items-center gap-0.5 py-2.5 text-xs font-medium transition-colors ${
              active === tab.id ? 'text-cyan-400' : 'text-white/45'
            }`}
          >
            <span className="text-lg leading-none">{tab.icon}</span>
            <span>{tab.label}</span>
          </button>
        ))}
      </div>
    </nav>
  )
}
