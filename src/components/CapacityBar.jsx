function CapacityBar({
  deviceSizeBytes,
  deviceSizeFormatted,
  musicPercentage,
  audiobooksPercentage,
  availablePercentage,
  usedPercentage,
  isOverCapacity,
  musicBytes,
  audiobooksBytes,
  totalUsed,
  formatSize
}) {
  if (!deviceSizeBytes || deviceSizeBytes === 0) {
    return null
  }

  return (
    <div className="mt-4 p-4 bg-white border border-gray-300 rounded-lg shadow-sm">
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm font-semibold text-gray-700">Device Capacity</span>
        <span className="text-sm text-gray-600">{deviceSizeFormatted} total</span>
      </div>
      
      {/* iTunes-style stacked progress bar */}
      <div className="relative h-10 bg-gray-200 rounded-lg overflow-hidden border-2 border-gray-300 shadow-inner">
        {/* Background: Available space */}
        <div
          className="absolute top-0 right-0 h-full bg-gray-100 transition-all duration-300 ease-out"
          style={{ width: `${Math.max(availablePercentage, 0)}%` }}
        >
          <div className="h-full bg-gradient-to-b from-gray-50 to-gray-100"></div>
        </div>
        
        {/* Music segment */}
        {musicPercentage > 0 && !isOverCapacity && (
          <div
            className="absolute top-0 left-0 h-full transition-all duration-300 ease-out z-10 bg-gradient-to-r from-blue-500 via-blue-600 to-blue-500"
            style={{ width: `${musicPercentage}%` }}
          >
            <div className="h-full bg-gradient-to-r from-transparent via-white/15 to-transparent"></div>
            {musicPercentage > 5 && (
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-xs font-bold text-white drop-shadow-md">
                  Music {musicPercentage.toFixed(1)}%
                </span>
              </div>
            )}
          </div>
        )}
        
        {/* Audiobooks segment */}
        {audiobooksPercentage > 0 && !isOverCapacity && (
          <div
            className="absolute top-0 h-full transition-all duration-300 ease-out border-l-2 border-white/50 z-10 bg-gradient-to-r from-purple-500 via-purple-600 to-purple-500"
            style={{
              left: `${musicPercentage}%`,
              width: `${audiobooksPercentage}%`
            }}
          >
            <div className="h-full bg-gradient-to-r from-transparent via-white/15 to-transparent"></div>
            {audiobooksPercentage > 5 && (
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-xs font-bold text-white drop-shadow-md">
                  Audiobooks {audiobooksPercentage.toFixed(1)}%
                </span>
              </div>
            )}
          </div>
        )}
        
        {/* Over capacity warning */}
        {isOverCapacity && (
          <div
            className="absolute top-0 left-0 h-full bg-red-500 transition-all duration-300 ease-out z-20"
            style={{ width: `${Math.min(usedPercentage, 100)}%` }}
          >
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-xs font-bold text-white drop-shadow-md">Over Capacity!</span>
            </div>
          </div>
        )}
      </div>
      
      {/* Capacity details with legend */}
      <div className="mt-4 grid grid-cols-2 gap-4 text-xs">
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 bg-gradient-to-r from-blue-500 to-blue-600 rounded"></div>
              <span className="text-gray-700 font-medium">Music</span>
            </div>
            <span className="text-gray-900 font-semibold">{formatSize(musicBytes)}</span>
          </div>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 bg-gradient-to-r from-purple-500 to-purple-600 rounded"></div>
              <span className="text-gray-700 font-medium">Audiobooks</span>
            </div>
            <span className="text-gray-900 font-semibold">{formatSize(audiobooksBytes)}</span>
          </div>
        </div>
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-4 h-4 bg-gray-100 border border-gray-300 rounded"></div>
              <span className="text-gray-700 font-medium">Available</span>
            </div>
            <span className="text-gray-900 font-semibold">
              {formatSize(Math.max(0, deviceSizeBytes - totalUsed))}
            </span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-gray-700 font-medium">Total Used</span>
            <span className="text-gray-900 font-semibold">{formatSize(totalUsed)}</span>
          </div>
        </div>
      </div>
    </div>
  )
}

export default CapacityBar
