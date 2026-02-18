import { useState, useEffect } from 'react'

function formatDuration(seconds) {
  if (seconds == null || seconds < 0) return '0:00'
  const m = Math.floor(seconds / 60)
  const s = Math.floor(seconds % 60)
  return `${m}:${s.toString().padStart(2, '0')}`
}

function PlaylistsTab({ mode = 'all', setMode, selectedPlaylistIds = [], setSelectedPlaylistIds }) {
  const [playlists, setPlaylists] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const togglePlaylist = (id) => {
    const sid = String(id)
    setSelectedPlaylistIds((prev) =>
      prev.includes(sid) ? prev.filter((i) => i !== sid) : [...prev, sid]
    )
  }

  const selectAllPlaylists = () => {
    setSelectedPlaylistIds(playlists.map((p) => String(p.id)))
  }

  const deselectAllPlaylists = () => {
    setSelectedPlaylistIds([])
  }

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError('')
    fetch('/api/playlists')
      .then((res) => res.json())
      .then((data) => {
        if (cancelled) return
        if (data.error) {
          setError(data.error)
          setPlaylists([])
        } else {
          setPlaylists(data.playlists || [])
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err.message || 'Failed to load playlists')
          setPlaylists([])
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  if (loading) {
    return (
      <div className="p-6 text-center text-gray-500">
        Loading playlists…
      </div>
    )
  }

  if (error) {
    return (
      <div className="p-6 rounded-lg bg-red-50 text-red-800">
        <p className="font-medium">Could not load playlists</p>
        <p className="text-sm mt-1">{error}</p>
      </div>
    )
  }

  if (playlists.length === 0) {
    return (
      <div className="p-6 text-center text-gray-500">
        No playlists found on your Subsonic server.
      </div>
    )
  }

  return (
    <div className="space-y-2">
      {/* Mode Selection */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <label className="flex items-center cursor-pointer">
          <input
            type="radio"
            name="playlistMode"
            value="all"
            checked={mode === 'all'}
            onChange={() => setMode('all')}
            className="mr-3 w-5 h-5 text-blue-600"
          />
          <span className="text-lg font-semibold text-gray-700 flex-1">Sync All Playlists</span>
          {mode === 'all' && (
            <span className="text-sm text-gray-600 font-medium">{playlists.length} playlist(s)</span>
          )}
        </label>
        <label className="flex items-center cursor-pointer mt-3">
          <input
            type="radio"
            name="playlistMode"
            value="selected"
            checked={mode === 'selected'}
            onChange={() => setMode('selected')}
            className="mr-3 w-5 h-5 text-blue-600"
          />
          <span className="text-lg font-semibold text-gray-700">Select Specific Playlists</span>
        </label>
      </div>

      {mode === 'selected' && (
        <>
          <p className="text-gray-600 mb-4">
            Select playlists to include ({playlists.length} total).
          </p>
          <div className="mb-4 flex gap-2">
            <button
              type="button"
              onClick={selectAllPlaylists}
              className="px-3 py-1.5 text-sm font-medium text-blue-600 hover:bg-blue-50 rounded border border-blue-200"
            >
              Select all
            </button>
            <button
              type="button"
              onClick={deselectAllPlaylists}
              className="px-3 py-1.5 text-sm font-medium text-gray-600 hover:bg-gray-100 rounded border border-gray-200"
            >
              Deselect all
            </button>
            {selectedPlaylistIds.length > 0 && (
              <span className="py-1.5 text-sm text-gray-500">
                {selectedPlaylistIds.length} selected
              </span>
            )}
          </div>
          <ul className="divide-y divide-gray-200 rounded-lg border border-gray-200 overflow-hidden bg-white">
            {playlists.map((p) => {
              const idStr = String(p.id)
              const isSelected = selectedPlaylistIds.includes(idStr)
              return (
                <li
                  key={p.id}
                  className="px-4 py-3 flex items-center gap-3 hover:bg-gray-50"
                >
                  <input
                    type="checkbox"
                    checked={isSelected}
                    onChange={() => togglePlaylist(p.id)}
                    className="w-5 h-5 rounded text-blue-600 focus:ring-blue-500"
                    aria-label={`Select playlist ${p.name}`}
                  />
                  <div className="min-w-0 flex-1">
                    <p className="font-medium text-gray-900 truncate">{p.name}</p>
                    <p className="text-sm text-gray-500">
                      {p.songCount ?? 0} tracks · {formatDuration(p.duration)} · {p.public ? 'Public' : 'Private'}
                      {p.owner ? ` · ${p.owner}` : ''}
                    </p>
                  </div>
                </li>
              )
            })}
          </ul>
        </>
      )}
    </div>
  )
}

export default PlaylistsTab
