import { useState, useEffect } from 'react'
import MusicTab from './components/MusicTab'
import AudiobooksTab from './components/AudiobooksTab'
import PlaylistsTab from './components/PlaylistsTab'
import CapacityBar from './components/CapacityBar'
import SelectionSummary from './components/SelectionSummary'

function App() {
  const [activeTab, setActiveTab] = useState('music')
  const [albumsByArtist, setAlbumsByArtist] = useState({})
  const [albums, setAlbums] = useState([])
  const [audiobooks, setAudiobooks] = useState([])
  const [selectedMusicAlbums, setSelectedMusicAlbums] = useState([])
  const [selectedAudiobooks, setSelectedAudiobooks] = useState([])
  const [musicMode, setMusicMode] = useState('all')
  const [audiobooksMode, setAudiobooksMode] = useState('all')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState('')
  const [messageType, setMessageType] = useState('success')
  const [musicTotalSizeFormatted, setMusicTotalSizeFormatted] = useState('0 B')
  const [audiobooksTotalSizeFormatted, setAudiobooksTotalSizeFormatted] = useState('0 B')
  const [deviceSizeGB, setDeviceSizeGB] = useState(160)
  const [deviceSizeBytes, setDeviceSizeBytes] = useState(0)
  const [deviceSizeFormatted, setDeviceSizeFormatted] = useState('0 B')
  const [subsonicConfigured, setSubsonicConfigured] = useState(false)
  const [selectedPlaylistIds, setSelectedPlaylistIds] = useState([])

  const formatSize = (bytes) => {
    if (bytes === 0) return '0 B'
    const units = ['B', 'KB', 'MB', 'GB', 'TB']
    const exp = Math.floor(Math.log(bytes) / Math.log(1024))
    const expClamped = Math.min(exp, units.length - 1)
    return `${(bytes / Math.pow(1024, expClamped)).toFixed(2)} ${units[expClamped]}`
  }

  const getMusicSelectionSizeBytes = () => {
    if (musicMode === 'all') {
      return Object.values(albumsByArtist)
        .flat()
        .reduce((sum, album) => sum + (album.size || 0), 0)
    } else {
      return Object.values(albumsByArtist)
        .flat()
        .filter(album => selectedMusicAlbums.includes(album.path))
        .reduce((sum, album) => sum + (album.size || 0), 0)
    }
  }

  const getAudiobooksSelectionSizeBytes = () => {
    if (audiobooksMode === 'all') {
      return audiobooks.reduce((sum, ab) => sum + (ab.size || 0), 0)
    } else {
      return audiobooks
        .filter(ab => selectedAudiobooks.includes(ab.path))
        .reduce((sum, ab) => sum + (ab.size || 0), 0)
    }
  }

  const getTotalSelectionSizeBytes = () => {
    return getMusicSelectionSizeBytes() + getAudiobooksSelectionSizeBytes()
  }

  const getUsedPercentage = () => {
    if (!deviceSizeBytes || deviceSizeBytes === 0) {
      return 0
    }
    const used = getTotalSelectionSizeBytes()
    return (used / deviceSizeBytes) * 100
  }

  const getMusicPercentage = () => {
    if (!deviceSizeBytes || deviceSizeBytes === 0) return 0
    const musicBytes = getMusicSelectionSizeBytes()
    return (musicBytes / deviceSizeBytes) * 100
  }

  const getAudiobooksPercentage = () => {
    if (!deviceSizeBytes || deviceSizeBytes === 0) return 0
    const audiobooksBytes = getAudiobooksSelectionSizeBytes()
    return (audiobooksBytes / deviceSizeBytes) * 100
  }

  const getAvailablePercentage = () => {
    return Math.max(0, 100 - getUsedPercentage())
  }

  const isOverCapacity = () => {
    if (!deviceSizeBytes || deviceSizeBytes === 0) {
      return false
    }
    return getUsedPercentage() > 100
  }

  const loadAlbums = async () => {
    setLoading(true)
    try {
      const response = await fetch('/api/albums')
      const data = await response.json()
      setAlbumsByArtist(data.albums_by_artist || {})
      setAlbums(data.albums || [])
      setAudiobooks(data.audiobooks || [])
      setMusicTotalSizeFormatted(data.total_size_formatted || '0 B')
      setAudiobooksTotalSizeFormatted(data.audiobooks_total_size_formatted || '0 B')
      
      const gb = parseInt(data.device_size_gb) || 160
      setDeviceSizeGB(gb)
      
      let bytes = 0
      if (data.device_size_bytes && parseFloat(data.device_size_bytes) > 0) {
        bytes = parseFloat(data.device_size_bytes)
      } else {
        bytes = gb * 1024 * 1024 * 1024
      }
      setDeviceSizeBytes(bytes)
      setDeviceSizeFormatted(data.device_size_formatted || formatSize(bytes))
      setSubsonicConfigured(!!data.subsonic_configured)

      const selection = data.selection || {}
      const musicSel = selection.music || {}
      const audiobooksSel = selection.audiobooks || {}
      const playlistsSel = selection.playlists || {}
      setSelectedPlaylistIds(playlistsSel.playlist_ids || [])

      if (musicSel.mode === 'selected') {
        setMusicMode('selected')
        setSelectedMusicAlbums([...(musicSel.albums || [])])
      } else {
        setMusicMode('all')
      }
      
      if (audiobooksSel.mode === 'selected') {
        setAudiobooksMode('selected')
        setSelectedAudiobooks([...(audiobooksSel.audiobooks || [])])
      } else {
        setAudiobooksMode('all')
      }
    } catch (error) {
      showMessage('Error loading data: ' + error.message, 'error')
    } finally {
      setLoading(false)
    }
  }

  const saveSelection = async () => {
    if ((musicMode === 'selected' && selectedMusicAlbums.length === 0) &&
        (audiobooksMode === 'selected' && selectedAudiobooks.length === 0)) {
      showMessage('Please select at least one item', 'error')
      return
    }

    setSaving(true)
    setMessage('')

    try {
      const response = await fetch('/api/selection', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          music_mode: musicMode,
          music_albums: selectedMusicAlbums,
          audiobooks_mode: audiobooksMode,
          audiobooks: selectedAudiobooks,
          playlist_ids: selectedPlaylistIds
        })
      })

      const data = await response.json()
      
      if (response.ok) {
        const musicCount = musicMode === 'all' ? 'all' : selectedMusicAlbums.length
        const abCount = audiobooksMode === 'all' ? 'all' : selectedAudiobooks.length
        const playlistCount = selectedPlaylistIds.length
        const parts = [
          `${musicCount} music album(s)`,
          `${abCount} audiobook(s)`
        ]
        if (subsonicConfigured) parts.push(`${playlistCount} playlist(s)`)
        showMessage(
          `Selection saved: ${parts.join(', ')}`,
          'success'
        )
      } else {
        showMessage('Error saving selection: ' + (data.message || 'Unknown error'), 'error')
      }
    } catch (error) {
      showMessage('Error saving selection: ' + error.message, 'error')
    } finally {
      setSaving(false)
    }
  }

  const showMessage = (text, type = 'success') => {
    setMessage(text)
    setMessageType(type)
    setTimeout(() => {
      setMessage('')
    }, 5000)
  }

  useEffect(() => {
    loadAlbums()
  }, [])

  return (
    <div className="bg-gray-100 min-h-screen py-8">
      <div className="max-w-5xl mx-auto px-4">
        <div className="bg-white rounded-lg shadow-lg p-6">
          <h1 className="text-3xl font-bold text-gray-800 mb-2">DAP Sync Selection</h1>
          <p className="text-gray-600 mb-6">Choose which music and audiobooks to sync to your DAP</p>

          {/* Tabs */}
          <div className="mb-6 border-b border-gray-200">
            <div className="flex space-x-1">
              <button
                onClick={() => setActiveTab('music')}
                className={`px-4 py-2 font-semibold transition-colors ${
                  activeTab === 'music'
                    ? 'border-b-2 border-blue-600 text-blue-600'
                    : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                Music
              </button>
              <button
                onClick={() => setActiveTab('audiobooks')}
                className={`px-4 py-2 font-semibold transition-colors ${
                  activeTab === 'audiobooks'
                    ? 'border-b-2 border-blue-600 text-blue-600'
                    : 'text-gray-500 hover:text-gray-700'
                }`}
              >
                Audiobooks
              </button>
              {subsonicConfigured && (
                <button
                  onClick={() => setActiveTab('playlists')}
                  className={`px-4 py-2 font-semibold transition-colors ${
                    activeTab === 'playlists'
                      ? 'border-b-2 border-blue-600 text-blue-600'
                      : 'text-gray-500 hover:text-gray-700'
                  }`}
                >
                  Playlists
                </button>
              )}
            </div>
          </div>

          {/* Music Tab */}
          {activeTab === 'music' && (
            <MusicTab
              albumsByArtist={albumsByArtist}
              albums={albums}
              selectedAlbums={selectedMusicAlbums}
              setSelectedAlbums={setSelectedMusicAlbums}
              mode={musicMode}
              setMode={setMusicMode}
              totalSizeFormatted={musicTotalSizeFormatted}
              loading={loading}
              formatSize={formatSize}
              getMusicSelectionSizeBytes={getMusicSelectionSizeBytes}
            />
          )}

          {/* Audiobooks Tab */}
          {activeTab === 'audiobooks' && (
            <AudiobooksTab
              audiobooks={audiobooks}
              selectedAudiobooks={selectedAudiobooks}
              setSelectedAudiobooks={setSelectedAudiobooks}
              mode={audiobooksMode}
              setMode={setAudiobooksMode}
              totalSizeFormatted={audiobooksTotalSizeFormatted}
              loading={loading}
              formatSize={formatSize}
              getAudiobooksSelectionSizeBytes={getAudiobooksSelectionSizeBytes}
            />
          )}

          {/* Playlists Tab (Subsonic) */}
          {subsonicConfigured && activeTab === 'playlists' && (
            <PlaylistsTab
              selectedPlaylistIds={selectedPlaylistIds}
              setSelectedPlaylistIds={setSelectedPlaylistIds}
            />
          )}

          {/* Capacity Bar */}
          <CapacityBar
            deviceSizeBytes={deviceSizeBytes}
            deviceSizeFormatted={deviceSizeFormatted}
            musicPercentage={getMusicPercentage()}
            audiobooksPercentage={getAudiobooksPercentage()}
            availablePercentage={getAvailablePercentage()}
            usedPercentage={getUsedPercentage()}
            isOverCapacity={isOverCapacity()}
            musicBytes={getMusicSelectionSizeBytes()}
            audiobooksBytes={getAudiobooksSelectionSizeBytes()}
            totalUsed={getTotalSelectionSizeBytes()}
            formatSize={formatSize}
          />

          {/* Save Button */}
          <div className="mt-6 flex justify-end gap-4">
            <button
              onClick={saveSelection}
              disabled={saving || (musicMode === 'selected' && selectedMusicAlbums.length === 0 && audiobooksMode === 'selected' && selectedAudiobooks.length === 0)}
              className="px-6 py-3 bg-green-600 text-white rounded-lg font-semibold hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition"
            >
              {saving ? 'Saving...' : 'Save Selection'}
            </button>
          </div>

          {/* Status Messages */}
          {message && (
            <div
              className={`mt-4 p-4 rounded-lg ${
                messageType === 'success' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
              }`}
            >
              <p>{message}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
