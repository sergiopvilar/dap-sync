require 'fileutils'
require_relative '../config.rb'
require_relative '../directories.rb'

module Fetchers
  class SyncSelection
    def self.read_sync_selection
      self.new.read_sync_selection
    end

    def initialize
      @music_mode = "all"
      @audiobooks_mode = "all"
      @music_albums = []
      @audiobooks_list = []
      @playlist_ids = []
    end

    def output
      {
        music: {
          mode: @music_mode,
          albums: @music_albums
        },
        audiobooks: {
          mode: @audiobooks_mode,
          audiobooks: @audiobooks_list
        },
        playlists: {
          playlist_ids: @playlist_ids
        }
      }
    end

    def read_sync_selection
      return output unless File.exist?(Config.internal_sync_selection_file)
    
      begin
        content = File.read(Config.internal_sync_selection_file).strip
        content.lines.each do |line|
          line = line.strip
          next if line.empty? || line.start_with?('#')
  
          if line == 'ALL_MUSIC=true'
            @music_mode = 'all'
          elsif line == 'ALL_AUDIOBOOKS=true'
            @audiobooks_mode = 'all'
          elsif line.start_with?('MUSIC_ALBUM=')
            @music_mode = 'selected'
            album_path = line.sub('MUSIC_ALBUM=', '').strip.gsub(Config.music_source, '')
            @music_albums << album_path unless album_path.empty?
          elsif line.start_with?('AUDIOBOOKS=')
            @audiobooks_mode = 'selected'
            audiobook_path = line.sub('AUDIOBOOKS=', '').strip
            @audiobooks_list << audiobook_path.gsub(Config.audiobooks_source, '') unless audiobook_path.empty?
          elsif line.start_with?('PLAYLIST_ID=')
            pid = line.sub('PLAYLIST_ID=', '').strip
            @playlist_ids << pid unless pid.empty?
          end
        end
  
        output
      end
    end
  end
end