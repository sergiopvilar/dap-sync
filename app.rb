#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'fileutils'
require 'net/http'
require 'uri'
require_relative 'src/config.rb'
require_relative 'src/directories.rb'
require_relative 'src/generators/playlist.rb'
require_relative 'src/generators/sync_script.rb'
require_relative 'src/generators/sync_selection.rb'
require_relative 'src/fetchers/sync_selection.rb'
require_relative 'src/fetchers/albums.rb'
require_relative 'src/fetchers/audiobooks.rb'
require_relative 'src/fetchers/playlists.rb'

set :bind, '0.0.0.0'
set :port, 3000
set :public_folder, File.join(File.dirname(__FILE__), 'public')
set :static, true

before do
  headers 'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers' => 'Content-Type'
end

options '*' do
  response.headers['Allow'] = 'HEAD,GET,PUT,POST,DELETE,OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept'
  200
end

get '/' do
  # Serve React app index.html
  index_path = File.join(File.dirname(__FILE__), 'public', 'index.html')
  send_file index_path
end

get '/api/albums' do
  content_type :json
  grouped = Fetchers::Albums.grouped_by_artist
  audiobooks = Fetchers::Audiobooks.all
  
  # Calculate total size of all albums
  total_size = 0
  grouped.each do |artist, albums|
    albums.each do |album|
      total_size += album[:size] || 0
    end
  end
  
  # Calculate total size of all audiobooks
  audiobooks_total_size = audiobooks.reduce(0) { |sum, ab| sum + (ab[:size] || 0) }
  
  # Convert GB to bytes (1 GB = 1024^3 bytes)
  # Use integer to avoid floating point precision issues
  device_size_bytes = (Config.device_size_gb * 1024 * 1024 * 1024).to_i
  
  payload = {
    albums_by_artist: grouped,
    albums: Fetchers::Albums.all,
    audiobooks: audiobooks,
    selection: Fetchers::SyncSelection.read_sync_selection,
    total_size: total_size,
    total_size_formatted: Directories.format_size(total_size),
    audiobooks_total_size: audiobooks_total_size,
    audiobooks_total_size_formatted: Directories.format_size(audiobooks_total_size),
    device_size_gb: Config.device_size_gb,
    device_size_bytes: device_size_bytes,
    device_size_formatted: Directories.format_size(device_size_bytes),
    subsonic_configured: File.exist?(Config.internal_navidrome_database)
  }
  payload.to_json
end

post '/api/selection' do
  content_type :json
  data = JSON.parse(request.body.read)
  
  music_mode = data['music_mode'] || data['mode'] || 'all'
  music_albums = data['music_albums'] || data['albums'] || []
  audiobooks_mode = data['audiobooks_mode'] || 'all'
  audiobooks_list = data['audiobooks'] || []
  playlist_ids = data['playlist_ids'] || []

  Generators::SyncSelection.generate_sync_selection(music_mode, music_albums, audiobooks_mode, audiobooks_list, playlist_ids)
  Generators::Playlist.generate_playlists(playlist_ids)
  Generators::SyncScript.generate_sync_script

  logger.info Config.dap_sync_output

  { success: true, message: "Selection saved successfully" }.to_json
end

get '/api/selection' do
  content_type :json
  read_sync_selection.to_json
end

get '/api/playlists' do
  content_type :json
  unless File.exist?(Config.internal_navidrome_database)
    status 503
    return { error: 'Subsonic not configured' }.to_json
  end

  {
    playlists: Fetchers::Playlists.all
  }.to_json
end
