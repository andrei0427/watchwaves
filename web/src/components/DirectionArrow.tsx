interface Props {
  degrees: number
  size?: number
  color?: string
}

export function DirectionArrow({ degrees, size = 20, color = 'white' }: Props) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      style={{ transform: `rotate(${degrees + 180}deg)`, display: 'inline-block', flexShrink: 0 }}
      aria-hidden="true"
    >
      <path
        d="M12 2 L7 20 L12 16 L17 20 Z"
        fill={color}
        opacity={0.9}
      />
    </svg>
  )
}
