require_relative '../config.rb'
require_relative '../directories.rb'

module Fetchers
  class Albums
    def self.all
      albums = []
      grouped_by_artist.each do |artist, album_list|
        album_list.each do |album|
          albums << album[:path]
        end
      end
      albums
    end

    def self.grouped_by_artist
      grouped = {}
      return grouped unless Dir.exist?(Config.internal_music_source)
      
      begin
        Dir.entries(Config.internal_music_source).sort.each do |item|
          next if item == '.' || item == '..'
          item_path = File.join(Config.internal_music_source, item)
          next unless File.directory?(item_path)
          
          # Check if this directory contains subdirectories (likely Artist/Album structure)
          has_subdirs = Dir.entries(item_path).any? { |sub| 
            sub != '.' && sub != '..' && File.directory?(File.join(item_path, sub))
          }
          
          if has_subdirs
            # Artist/Album structure: item is artist, subdirs are albums
            artist = item
            grouped[artist] ||= []
            Dir.entries(item_path).sort.each do |album|
              next if album == '.' || album == '..'
              album_path = File.join(item_path, album)
              if File.directory?(album_path)
                full_path = File.join(artist, album)
                size = Directories.calculate_directory_size(album_path)
                grouped[artist] << { 
                  name: album, 
                  path: full_path,
                  size: size,
                  size_formatted: Directories.format_size(size)
                }
              end
            end
          else
            # Flat structure: assume format "Artist - Album" or just album name
            if item.include?(' - ')
              parts = item.split(' - ', 2)
              artist = parts[0].strip
              album_name = parts[1].strip
            else
              artist = 'Unknown Artist'
              album_name = item
            end
            grouped[artist] ||= []
            size = Directories.calculate_directory_size(item_path)
            grouped[artist] << { 
              name: album_name, 
              path: item,
              size: size,
              size_formatted: Directories.format_size(size)
            }
          end
        end
      rescue Errno::EACCES
        # Permission denied, return empty hash
      end
      
      grouped
    end
  end
end