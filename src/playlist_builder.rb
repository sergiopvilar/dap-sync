require 'json'
require 'net/http'
require 'uri'
require 'fileutils'

class PlaylistBuilder
  PLAYLISTS_DIR = '/data/Playlists'

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
  end

  def fetch_songs
    subsonic_url = (ENV['SUBSONIC_URL'] || '').strip
    subsonic_username = (ENV['SUBSONIC_USERNAME'] || '').strip
    subsonic_password = (ENV['SUBSONIC_PASSWORD'] || '').strip
    return @songs if subsonic_url.empty? || subsonic_username.empty? || subsonic_password.empty?

    base = subsonic_url.sub(%r{/+$}, '')
    path = '/rest/getPlaylist'
    params = {
      u: subsonic_username,
      p: subsonic_password,
      v: '1.16.0',
      c: 'dap-sync',
      f: 'json',
      id: @playlist_id
    }

    query = URI.encode_www_form(params)
    url = URI("#{base}#{path}?#{query}")
    res = Net::HTTP.get_response(url)
    data = JSON.parse(res.body)
    return @songs unless data.dig('subsonic-response', 'status') == 'ok'

    playlist = data.dig('subsonic-response', 'playlist') || {}
    @playlist_name = playlist['name'] || "playlist_#{@playlist_id}"
    entries = playlist['entry']
    entries = [entries] if entries.is_a?(Hash)
    entries = Array(entries)

    prefix = self.class.path_prefix
    @songs = entries.filter_map do |entry|
      path_str = entry['path'].to_s.strip
      next nil if path_str.empty?
      path_str = "/#{path_str}" unless path_str.start_with?('/')
      if prefix.empty?
        path_str
      else
        base = prefix.end_with?('/') ? prefix : "#{prefix}/"
        "#{base}music#{path_str}"
      end
    end
    @songs
  end

  def self.path_prefix
    @path_prefix ||= begin
      p = (ENV['PLAYLIST_PATH_PREFIX'] || '/<HDD0>').strip
      p.empty? ? '' : p
    end
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
    content = @songs.join("\n") + "\n"
    File.write(file_path, content)
    file_path
  end
end