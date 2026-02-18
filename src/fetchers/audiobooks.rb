require_relative '../config.rb'
require_relative '../directories.rb'

module Fetchers
  class Audiobooks
    def self.all
      audiobooks = []
      return audiobooks unless Dir.exist?(Config.internal_audiobooks_source)
      
      begin
        Dir.entries(Config.internal_audiobooks_source).sort.each do |item|
          next if item == '.' || item == '..'
          item_path = File.join(Config.internal_audiobooks_source, item)
          
          # Handle both directories and files
          if File.directory?(item_path)
            size = Directories.calculate_directory_size(item_path)
            audiobooks << {
              name: item,
              path: item,
              size: size,
              size_formatted: Directories.format_size(size)
            }
          elsif File.file?(item_path)
            # It's a file (e.g., .m4b, .mp3)
            size = File.size(item_path)
            audiobooks << {
              name: item,
              path: item,
              size: size,
              size_formatted: Directories.format_size(size)
            }
          end
        end
      rescue Errno::EACCES => e
        # Permission denied, return empty list
        logger.error "Error accessing audiobooks: #{e.message}"
      end
      
      audiobooks
    end
  end
end