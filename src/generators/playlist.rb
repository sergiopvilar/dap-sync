require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require_relative '../navidrome.rb'

module Generators
  class Playlist
    PLAYLISTS_DIR = '/data/Playlists'
    PATH_PREFIX = '/<HDD0>/music/'

    def self.get_playlist_ids(playlist_mode, playlist_ids)
      return playlist_ids if playlist_mode != 'all'
      
      Navidrome.new.get_playlists.map { |playlist| playlist[:id] }
    end

    def self.generate_playlists(playlist_mode, playlist_ids)
      ids = get_playlist_ids(playlist_mode, playlist_ids)
      ids.each do |id|
        next if id.to_s.strip.empty?
        self.new(id.to_s.strip).write_playlist_file
      end
    end

    def self.reset_playlists_dir
      if File.directory?(PLAYLISTS_DIR)
        Dir.each_child(PLAYLISTS_DIR) { |e| FileUtils.rm_r(File.join(PLAYLISTS_DIR, e)) }
      else
        FileUtils.mkdir_p(PLAYLISTS_DIR)
      end
    end

    def initialize(playlist_id)
      @playlist_id = playlist_id
      @songs = []
      @playlist_name = nil
      @navidrome = Navidrome.new
    end

    def fetch_songs
      songs = @navidrome.get_playlist_songs(@playlist_id)
      @playlist_name = @navidrome.get_playlist_name(@playlist_id)
      @songs = songs.map { |song| @navidrome.get_song_path(song) }
      @songs
    end

    def write_playlist_file
      fetch_songs if @songs.empty? && @playlist_name.nil?
      return nil if @songs.empty?

      name = @playlist_name || "playlist_#{@playlist_id}"
      safe_name = name.gsub(%r{[^\p{Alnum}\s\-_.]}, '_').strip
      safe_name = "playlist_#{@playlist_id}" if safe_name.empty?
      safe_name += '.m3u8' unless safe_name.end_with?('.m3u8')

      FileUtils.mkdir_p(PLAYLISTS_DIR)
      file_path = File.join(PLAYLISTS_DIR, safe_name)
      content = @songs.map { |song| "#{PATH_PREFIX}#{song}" }.join("\n") + "\n"
      File.write(file_path, content)
      file_path
    end
  end
end