import { useState, useEffect, useCallback, useRef } from 'react'
import type { WaveCondition } from '../types/WaveCondition'
import { fetchMarineData } from '../api/marineApi'
import { CACHE_TTL_MS } from '../data/constants'

interface MarineDataState {
  conditions: WaveCondition[]
  isLoading: boolean
  error: string | null
  lastUpdated: Date | null
  refresh: () => void
}

interface Cache {
  conditions: WaveCondition[]
  fetchedAt: number
}

let cache: Cache | null = null

export function useMarineData(): MarineDataState {
  const [conditions, setConditions] = useState<WaveCondition[]>(cache?.conditions ?? [])
  const [isLoading, setIsLoading] = useState(cache === null)
  const [error, setError] = useState<string | null>(null)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(
    cache ? new Date(cache.fetchedAt) : null
  )
  const abortRef = useRef<AbortController | null>(null)

  const load = useCallback(async (force = false) => {
    const now = Date.now()
    if (!force && cache && now - cache.fetchedAt < CACHE_TTL_MS) {
      setConditions(cache.conditions)
      setLastUpdated(new Date(cache.fetchedAt))
      setIsLoading(false)
      return
    }

    abortRef.current?.abort()
    abortRef.current = new AbortController()

    setIsLoading(true)
    setError(null)

    try {
      const data = await fetchMarineData()
      cache = { conditions: data, fetchedAt: Date.now() }
      setConditions(data)
      setLastUpdated(new Date())
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') return
      setError(err instanceof Error ? err.message : 'Failed to load marine data')
    } finally {
      setIsLoading(false)
    }
  }, [])

  const refresh = useCallback(() => {
    cache = null
    void load(true)
  }, [load])

  useEffect(() => {
    void load()
    return () => abortRef.current?.abort()
  }, [load])

  return { conditions, isLoading, error, lastUpdated, refresh }
}
