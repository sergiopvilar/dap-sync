function SelectionSummary({
  musicMode,
  audiobooksMode,
  musicBytes,
  audiobooksBytes,
  totalBytes,
  formatSize
}) {
  const getMusicSelectionSize = () => {
    if (musicMode === 'all') {
      return `${formatSize(musicBytes)} (all)`
    } else {
      // This would need the selected count, but for now just show the size
      return formatSize(musicBytes)
    }
  }

  const getAudiobooksSelectionSize = () => {
    if (audiobooksMode === 'all') {
      return `${formatSize(audiobooksBytes)} (all)`
    } else {
      return formatSize(audiobooksBytes)
    }
  }

  return (
    <div className="mt-6 p-4 bg-gradient-to-r from-purple-50 to-blue-50 border-2 border-purple-200 rounded-lg">
      <h3 className="text-lg font-bold text-gray-800 mb-3">Total Sync Size</h3>
      <div className="space-y-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-700">Music:</span>
          <span className="font-semibold text-gray-900">{getMusicSelectionSize()}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-700">Audiobooks:</span>
          <span className="font-semibold text-gray-900">{getAudiobooksSelectionSize()}</span>
        </div>
        <div className="pt-2 mt-2 border-t border-purple-200 flex items-center justify-between">
          <span className="font-bold text-lg text-gray-800">Total:</span>
          <span className="font-bold text-xl text-purple-700">{formatSize(totalBytes)}</span>
        </div>
      </div>
    </div>
  )
}

export default SelectionSummary
