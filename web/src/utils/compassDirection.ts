const DIRECTIONS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'] as const
type Direction = typeof DIRECTIONS[number]

export function compassDirection(degrees: number): Direction {
  const normalized = ((degrees % 360) + 360) % 360
  const index = Math.round(normalized / 45) % 8
  return DIRECTIONS[index]
}
