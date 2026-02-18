import { useState } from 'react'

function MusicTab({
  albumsByArtist,
  albums,
  selectedAlbums,
  setSelectedAlbums,
  mode,
  setMode,
  totalSizeFormatted,
  loading,
  formatSize,
  getMusicSelectionSizeBytes
}) {
  const isArtistSelected = (artist) => {
    const artistAlbums = albumsByArtist[artist] || []
    return artistAlbums.length > 0 && artistAlbums.every(album => 
      selectedAlbums.includes(album.path)
    )
  }

  const toggleArtist = (artist, checked) => {
    const artistAlbums = albumsByArtist[artist] || []
    const artistPaths = artistAlbums.map(a => a.path)

    if (checked) {
      setSelectedAlbums([...new Set([...selectedAlbums, ...artistPaths])])
    } else {
      setSelectedAlbums(selectedAlbums.filter(path => !artistPaths.includes(path)))
    }
  }

  const getArtistAlbumCount = (artist) => {
    return (albumsByArtist[artist] || []).length
  }

  const getArtistSize = (artist) => {
    const albums = albumsByArtist[artist] || []
    const totalBytes = albums.reduce((sum, album) => sum + (album.size || 0), 0)
    return formatSize(totalBytes)
  }

  const getTotalSelectedSize = () => {
    const totalBytes = Object.values(albumsByArtist)
      .flat()
      .filter(album => selectedAlbums.includes(album.path))
      .reduce((sum, album) => sum + (album.size || 0), 0)
    return `Total: ${formatSize(totalBytes)}`
  }

  const selectAll = () => {
    setSelectedAlbums([...albums])
  }

  const deselectAll = () => {
    setSelectedAlbums([])
  }

  return (
    <div>
      {/* Mode Selection */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <label className="flex items-center cursor-pointer">
          <input
            type="radio"
            name="musicMode"
            value="all"
            checked={mode === 'all'}
            onChange={() => setMode('all')}
            className="mr-3 w-5 h-5 text-blue-600"
          />
          <span className="text-lg font-semibold text-gray-700 flex-1">Sync All Albums</span>
          {mode === 'all' && (
            <span className="text-sm text-gray-600 font-medium">{totalSizeFormatted}</span>
          )}
        </label>
        <label className="flex items-center cursor-pointer mt-3">
          <input
            type="radio"
            name="musicMode"
            value="selected"
            checked={mode === 'selected'}
            onChange={() => setMode('selected')}
            className="mr-3 w-5 h-5 text-blue-600"
          />
          <span className="text-lg font-semibold text-gray-700">Select Specific Albums</span>
        </label>
      </div>

      {/* Album List */}
      {mode === 'selected' && (
        <div>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-xl font-semibold text-gray-700">Available Albums</h2>
            <div className="flex gap-2">
              <button
                onClick={selectAll}
                className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 transition"
              >
                Select All
              </button>
              <button
                onClick={deselectAll}
                className="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition"
              >
                Deselect All
              </button>
            </div>
          </div>

          <div className="max-h-96 overflow-y-auto border border-gray-200 rounded-lg">
            {loading ? (
              <div className="text-center py-8 text-gray-500">Loading albums...</div>
            ) : Object.keys(albumsByArtist).length === 0 ? (
              <div className="text-center py-8 text-gray-500">No albums found</div>
            ) : (
              <div className="divide-y divide-gray-200">
                {Object.entries(albumsByArtist).map(([artist, artistAlbums]) => (
                  <div key={artist} className="hover:bg-gray-50 transition-colors">
                    {/* Artist Row */}
                    <label className="flex items-center px-4 py-2 cursor-pointer border-b border-gray-100">
                      <input
                        type="checkbox"
                        checked={isArtistSelected(artist)}
                        onChange={(e) => toggleArtist(artist, e.target.checked)}
                        className="mr-3 w-4 h-4 text-blue-600 rounded"
                      />
                      <span className="font-semibold text-gray-800 flex-1">{artist}</span>
                      <span className="text-sm text-gray-500">{getArtistSize(artist)}</span>
                      <span className="text-xs text-gray-400 ml-2">({getArtistAlbumCount(artist)} albums)</span>
                    </label>
                    {/* Albums under artist */}
                    <div className="bg-gray-50/50">
                      {artistAlbums.map((album) => (
                        <label
                          key={album.path}
                          className="flex items-center px-4 py-1.5 hover:bg-gray-100 cursor-pointer pl-12"
                        >
                          <input
                            type="checkbox"
                            value={album.path}
                            checked={selectedAlbums.includes(album.path)}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setSelectedAlbums([...selectedAlbums, album.path])
                              } else {
                                setSelectedAlbums(selectedAlbums.filter(p => p !== album.path))
                              }
                            }}
                            className="mr-3 w-4 h-4 text-blue-600 rounded"
                          />
                          <span className="text-gray-700 flex-1">{album.name}</span>
                          <span className="text-sm text-gray-500">{album.size_formatted || '0 B'}</span>
                        </label>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Selection Summary */}
          <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-center justify-between">
              <div className="text-sm">
                <span className="font-semibold text-blue-900">{selectedAlbums.length}</span>
                <span className="text-blue-700"> album(s) selected</span>
              </div>
              <div className="text-sm font-semibold text-blue-900">{getTotalSelectedSize()}</div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default MusicTab
