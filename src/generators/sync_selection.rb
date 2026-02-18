require 'fileutils'
require_relative '../config.rb'

module Generators
  class SyncSelection
    def self.generate_sync_selection(music_mode, music_albums, audiobooks_mode, audiobooks_list, playlist_ids = [])
    
      lines = []
      # Music: flag for "all" or list of selected albums
      if music_mode.to_s == "all"
        lines << "ALL_MUSIC=true"
      else
        (music_albums || []).each do |path|
          album_path = convert_to_host_path(path.to_s, Config.internal_music_source, Config.music_source)
          lines << "MUSIC_ALBUM=#{album_path}"
        end
      end
      # Audiobooks: flag for "all" or list of selected audiobooks
      if audiobooks_mode.to_s == "all"
        lines << "ALL_AUDIOBOOKS=true"
      else
        (audiobooks_list || []).each do |path|
          audiobook_path = convert_to_host_path(path.to_s, Config.internal_audiobooks_source, Config.audiobooks_source)
          lines << "AUDIOBOOKS=#{audiobook_path}"
        end
      end
      # Subsonic playlist IDs (for future sync)
      (playlist_ids || []).each do |id|
        lines << "PLAYLIST_ID=#{id.to_s.strip}" unless id.to_s.strip.empty?
      end
    
      content = lines.join("\n") + "\n"
      File.write(Config.internal_sync_selection_file, content)
      File.chmod(0o755, Config.internal_sync_selection_file)
    end

    def self.convert_to_host_path(path, container_source, host_directory)
      # Normalize container_source to remove trailing slash for comparison
      container_base = container_source.end_with?('/') ? container_source[0..-2] : container_source
      container_prefix = "#{container_base}/"
      
      # Normalize host_directory to ensure it ends with /
      host_dir = host_directory.end_with?('/') ? host_directory : "#{host_directory}/"
      
      # If path already starts with host_directory, return as-is
      return path if path.start_with?(host_dir)
      
      # Remove container path prefix if present (e.g., /music/ or /audiobooks/)
      if path.start_with?(container_prefix)
        relative_path = path[container_prefix.length..-1]
      elsif path.start_with?('/music/')
        relative_path = path[7..-1]
      elsif path.start_with?('/audiobooks/')
        relative_path = path[12..-1]
      elsif path.start_with?('/')
        # Already absolute but not container path - assume it's already a host path
        return path
      else
        # Relative path
        relative_path = path
      end
      
      # Remove leading slash from relative_path if present
      relative_path = relative_path[1..-1] if relative_path.start_with?('/')
      
      "#{host_dir}#{relative_path}"
    end
  end
end