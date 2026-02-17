function AudiobooksTab({
  audiobooks,
  selectedAudiobooks,
  setSelectedAudiobooks,
  mode,
  setMode,
  totalSizeFormatted,
  loading,
  formatSize,
  getAudiobooksSelectionSizeBytes
}) {
  const getTotalSelectedSize = () => {
    const totalBytes = audiobooks
      .filter(ab => selectedAudiobooks.includes(ab.path))
      .reduce((sum, ab) => sum + (ab.size || 0), 0)
    return `Total: ${formatSize(totalBytes)}`
  }

  const selectAll = () => {
    setSelectedAudiobooks(audiobooks.map(ab => ab.path))
  }

  const deselectAll = () => {
    setSelectedAudiobooks([])
  }

  return (
    <div>
      {/* Mode Selection */}
      <div className="mb-6 p-4 bg-gray-50 rounded-lg">
        <label className="flex items-center cursor-pointer">
          <input
            type="radio"
            name="audiobooksMode"
            value="all"
            checked={mode === 'all'}
            onChange={() => setMode('all')}
            className="mr-3 w-5 h-5 text-blue-600"
          />
          <span className="text-lg font-semibold text-gray-700 flex-1">Sync All Audiobooks</span>
          {mode === 'all' && (
            <span className="text-sm text-gray-600 font-medium">{totalSizeFormatted}</span>
          )}
        </label>
        <label className="flex items-center cursor-pointer mt-3">
          <input
            type="radio"
            name="audiobooksMode"
            value="selected"
            checked={mode === 'selected'}
            onChange={() => setMode('selected')}
            className="mr-3 w-5 h-5 text-blue-600"
          />
          <span className="text-lg font-semibold text-gray-700">Select Specific Audiobooks</span>
        </label>
      </div>

      {/* Audiobooks List */}
      {mode === 'selected' && (
        <div>
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-xl font-semibold text-gray-700">Available Audiobooks</h2>
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
              <div className="text-center py-8 text-gray-500">Loading audiobooks...</div>
            ) : audiobooks.length === 0 ? (
              <div className="text-center py-8 text-gray-500">No audiobooks found</div>
            ) : (
              <div className="divide-y divide-gray-200">
                {audiobooks.map((audiobook) => (
                  <label
                    key={audiobook.path}
                    className="flex items-center px-4 py-2 hover:bg-gray-50 cursor-pointer"
                  >
                    <input
                      type="checkbox"
                      value={audiobook.path}
                      checked={selectedAudiobooks.includes(audiobook.path)}
                      onChange={(e) => {
                        if (e.target.checked) {
                          setSelectedAudiobooks([...selectedAudiobooks, audiobook.path])
                        } else {
                          setSelectedAudiobooks(selectedAudiobooks.filter(p => p !== audiobook.path))
                        }
                      }}
                      className="mr-3 w-4 h-4 text-blue-600 rounded"
                    />
                    <span className="text-gray-700 flex-1">{audiobook.name}</span>
                    <span className="text-sm text-gray-500">{audiobook.size_formatted || '0 B'}</span>
                  </label>
                ))}
              </div>
            )}
          </div>

          {/* Selection Summary */}
          <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-center justify-between">
              <div className="text-sm">
                <span className="font-semibold text-blue-900">{selectedAudiobooks.length}</span>
                <span className="text-blue-700"> audiobook(s) selected</span>
              </div>
              <div className="text-sm font-semibold text-blue-900">{getTotalSelectedSize()}</div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default AudiobooksTab
