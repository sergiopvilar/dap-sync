#!/usr/bin/env ruby
require 'sinatra'
require 'json'
require 'fileutils'

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

# Configuration - can be overridden via environment variables
MUSIC_SOURCE = ENV.fetch('MUSIC_SOURCE', '/music')
AUDIOBOOKS_SOURCE = ENV.fetch('AUDIOBOOKS_SOURCE', '/audiobooks')
# MUSIC_DIRECTORY and AUDIOBOOKS_DIRECTORY should be host paths, not container paths
# These are used to write full host paths to sync_selection.txt
MUSIC_DIRECTORY = ENV.fetch('MUSIC_DIRECTORY', '/Users/sergio/Music/Music/Media.localized/Music/')
AUDIOBOOKS_DIRECTORY = ENV.fetch('AUDIOBOOKS_DIRECTORY', '/Users/sergio/Library/OpenAudible/books/')
MUSIC_DESTINATION = ENV.fetch('MUSIC_DESTINATION', '/Users/sergio/sync/music/')
AUDIOBOOKS_DESTINATION = ENV.fetch('AUDIOBOOKS_DESTINATION', '/Users/sergio/sync/audiobooks/')
SYNC_SELECTION_FILE = ENV.fetch('SYNC_SELECTION_FILE', '/data/sync_selection.txt')
DAP_SYNC_TEMPLATE = ENV.fetch('DAP_SYNC_TEMPLATE', File.join(File.dirname(__FILE__), 'dap_sync.sh'))
DAP_SYNC_OUTPUT = ENV.fetch('DAP_SYNC_OUTPUT', '/data/dap_sync.sh')
DEVICE_SIZE_GB = ENV.fetch('DEVICE_SIZE', '160').to_i

def calculate_directory_size(path)
  return 0 unless Dir.exist?(path)
  total = 0
  begin
    Dir.glob(File.join(path, '**', '*')).each do |file|
      total += File.size(file) if File.file?(file)
    end
  rescue Errno::EACCES, Errno::ENOENT
    # Permission denied or file not found, return 0
  end
  total
end

def format_size(bytes)
  return "0 B" if bytes == 0
  units = ['B', 'KB', 'MB', 'GB', 'TB']
  exp = (Math.log(bytes) / Math.log(1024)).floor
  exp = units.length - 1 if exp >= units.length
  "#{(bytes / (1024.0 ** exp)).round(2)} #{units[exp]}"
end

def get_albums_grouped_by_artist
  grouped = {}
  return grouped unless Dir.exist?(MUSIC_SOURCE)
  
  begin
    Dir.entries(MUSIC_SOURCE).sort.each do |item|
      next if item == '.' || item == '..'
      item_path = File.join(MUSIC_SOURCE, item)
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
            size = calculate_directory_size(album_path)
            grouped[artist] << { 
              name: album, 
              path: full_path,
              size: size,
              size_formatted: format_size(size)
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
        size = calculate_directory_size(item_path)
        grouped[artist] << { 
          name: album_name, 
          path: item,
          size: size,
          size_formatted: format_size(size)
        }
      end
    end
  rescue Errno::EACCES
    # Permission denied, return empty hash
  end
  
  grouped
end

def get_all_albums
  albums = []
  get_albums_grouped_by_artist.each do |artist, album_list|
    album_list.each do |album|
      albums << album[:path]
    end
  end
  albums
end

def get_audiobooks
  audiobooks = []
  return audiobooks unless Dir.exist?(AUDIOBOOKS_SOURCE)
  
  begin
    Dir.entries(AUDIOBOOKS_SOURCE).sort.each do |item|
      next if item == '.' || item == '..'
      item_path = File.join(AUDIOBOOKS_SOURCE, item)
      
      # Handle both directories and files
      if File.directory?(item_path)
        size = calculate_directory_size(item_path)
        audiobooks << {
          name: item,
          path: item,
          size: size,
          size_formatted: format_size(size)
        }
      elsif File.file?(item_path)
        # It's a file (e.g., .m4b, .mp3)
        size = File.size(item_path)
        audiobooks << {
          name: item,
          path: item,
          size: size,
          size_formatted: format_size(size)
        }
      end
    end
  rescue Errno::EACCES => e
    # Permission denied, return empty list
    puts "Error accessing audiobooks: #{e.message}"
  end
  
  audiobooks
end

def read_sync_selection
  return { music: { mode: "all", albums: [] }, audiobooks: { mode: "all", audiobooks: [] } } unless File.exist?(SYNC_SELECTION_FILE)
  
  begin
    content = File.read(SYNC_SELECTION_FILE).strip
    
    # Try to parse new format (ALL_MUSIC/ALL_AUDIOBOOKS flags or MUSIC_ALBUM= / AUDIOBOOKS= lines)
    if content.include?('ALL_MUSIC=') || content.include?('ALL_AUDIOBOOKS=') || content.include?('MUSIC_ALBUM=') || content.include?('AUDIOBOOKS=')
      music_albums = []
      audiobooks_list = []
      music_mode = nil
      audiobooks_mode = nil

      content.lines.each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')

        if line == 'ALL_MUSIC=true'
          music_mode = 'all'
        elsif line == 'ALL_AUDIOBOOKS=true'
          audiobooks_mode = 'all'
        elsif line.start_with?('MUSIC_ALBUM=')
          music_mode = 'selected' if music_mode.nil?
          album_path = line.sub('MUSIC_ALBUM=', '').strip
          music_albums << album_path unless album_path.empty?
        elsif line.start_with?('AUDIOBOOKS=')
          audiobooks_mode = 'selected' if audiobooks_mode.nil?
          audiobook_path = line.sub('AUDIOBOOKS=', '').strip
          audiobooks_list << audiobook_path unless audiobook_path.empty?
        end
      end

      # Infer mode from list if flag was not set (backward compatibility)
      all_albums = get_all_albums
      all_audiobooks = get_audiobooks.map { |ab| ab[:path] }

      relative_music = music_albums.map do |path|
        if path.start_with?(MUSIC_DIRECTORY)
          path.sub(/^#{Regexp.escape(MUSIC_DIRECTORY)}/, '')
        elsif path.start_with?('/')
          path
        else
          path
        end
      end

      relative_audiobooks = audiobooks_list.map do |path|
        if path.start_with?(AUDIOBOOKS_DIRECTORY)
          path.sub(/^#{Regexp.escape(AUDIOBOOKS_DIRECTORY)}/, '')
        elsif path.start_with?('/')
          path
        else
          path
        end
      end

      music_mode = (relative_music.sort == all_albums.sort) ? 'all' : 'selected' if music_mode.nil?
      audiobooks_mode = (relative_audiobooks.sort == all_audiobooks.sort) ? 'all' : 'selected' if audiobooks_mode.nil?

      return {
        music: {
          mode: music_mode,
          albums: relative_music
        },
        audiobooks: {
          mode: audiobooks_mode,
          audiobooks: relative_audiobooks
        }
      }
    end
    
    # Try to parse old format with MUSIC_MODE= (for backward compatibility)
    if content.include?('MUSIC_MODE=') || content.include?('AUDIOBOOKS_MODE=')
      music_mode = "all"
      music_albums = []
      audiobooks_mode = "all"
      audiobooks_list = []
      
      content.lines.each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')
        
        if line.start_with?('MUSIC_MODE=')
          music_mode = line.sub('MUSIC_MODE=', '').strip
        elsif line.start_with?('MUSIC_ALBUM=')
          album_path = line.sub('MUSIC_ALBUM=', '').strip
          music_albums << album_path unless album_path.empty?
        elsif line.start_with?('AUDIOBOOKS_MODE=')
          audiobooks_mode = line.sub('AUDIOBOOKS_MODE=', '').strip
        elsif line.start_with?('AUDIOBOOKS=')
          audiobook_path = line.sub('AUDIOBOOKS=', '').strip
          audiobooks_list << audiobook_path unless audiobook_path.empty?
        end
      end
      
      # Convert full paths back to relative paths for display
      relative_music = music_albums.map do |path|
        if path.start_with?(MUSIC_DIRECTORY)
          path.sub(/^#{Regexp.escape(MUSIC_DIRECTORY)}/, '')
        elsif path.start_with?('/')
          path
        else
          path
        end
      end
      
      relative_audiobooks = audiobooks_list.map do |path|
        if path.start_with?(AUDIOBOOKS_DIRECTORY)
          path.sub(/^#{Regexp.escape(AUDIOBOOKS_DIRECTORY)}/, '')
        elsif path.start_with?('/')
          path
        else
          path
        end
      end
      
      return {
        music: {
          mode: music_mode,
          albums: relative_music
        },
        audiobooks: {
          mode: audiobooks_mode,
          audiobooks: relative_audiobooks
        }
      }
    end
    
    # Try to parse as JSON (old format, for backward compatibility)
    if content.start_with?('{')
      parsed = JSON.parse(content)
      music_albums = parsed['music']&.dig('albums') || []
      audiobooks_list = parsed['audiobooks']&.dig('audiobooks') || []
      
      relative_music = music_albums.map do |path|
        if path.start_with?(MUSIC_DIRECTORY)
          path.sub(/^#{Regexp.escape(MUSIC_DIRECTORY)}/, '')
        elsif path.start_with?('/')
          path
        else
          path
        end
      end
      
      relative_audiobooks = audiobooks_list.map do |path|
        if path.start_with?(AUDIOBOOKS_DIRECTORY)
          path.sub(/^#{Regexp.escape(AUDIOBOOKS_DIRECTORY)}/, '')
        elsif path.start_with?('/')
          path
        else
          path
        end
      end
      
      return {
        music: {
          mode: parsed['music']&.dig('mode') || 'all',
          albums: relative_music
        },
        audiobooks: {
          mode: parsed['audiobooks']&.dig('mode') || 'all',
          audiobooks: relative_audiobooks
        }
      }
    end
    
    # Legacy format: just "*" or list of albums
    if content == "*" || content.empty?
      { music: { mode: "all", albums: [] }, audiobooks: { mode: "all", audiobooks: [] } }
    else
      albums = content.lines.map(&:strip).reject(&:empty?)
      { music: { mode: "selected", albums: albums }, audiobooks: { mode: "all", audiobooks: [] } }
    end
  rescue => e
    { music: { mode: "all", albums: [] }, audiobooks: { mode: "all", audiobooks: [] } }
  end
end

def convert_to_host_path(path, container_source, host_directory)
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

def write_sync_selection(music_mode, music_albums, audiobooks_mode, audiobooks_list)
  FileUtils.mkdir_p(File.dirname(SYNC_SELECTION_FILE))

  lines = []
  # Music: flag for "all" or list of selected albums
  if music_mode.to_s == "all"
    lines << "ALL_MUSIC=true"
  else
    (music_albums || []).each do |path|
      album_path = convert_to_host_path(path.to_s, MUSIC_SOURCE, MUSIC_DIRECTORY)
      lines << "MUSIC_ALBUM=#{album_path}"
    end
  end
  # Audiobooks: flag for "all" or list of selected audiobooks
  if audiobooks_mode.to_s == "all"
    lines << "ALL_AUDIOBOOKS=true"
  else
    (audiobooks_list || []).each do |path|
      audiobook_path = convert_to_host_path(path.to_s, AUDIOBOOKS_SOURCE, AUDIOBOOKS_DIRECTORY)
      lines << "AUDIOBOOKS=#{audiobook_path}"
    end
  end

  content = lines.join("\n") + "\n"
  File.write(SYNC_SELECTION_FILE, content)

  # Process dap_sync.sh template and save to /data with env vars substituted
  process_dap_sync_template
rescue StandardError => e
  puts "Error writing sync selection: #{e.message}"
  raise
end

def process_dap_sync_template
  return unless File.exist?(DAP_SYNC_TEMPLATE)

  FileUtils.mkdir_p(File.dirname(DAP_SYNC_OUTPUT))

  template_content = File.read(DAP_SYNC_TEMPLATE)
  processed_content = template_content
    .gsub('{{SYNC_SELECTION_FILE}}', SYNC_SELECTION_FILE)
    .gsub('{{MUSIC_DESTINATION}}', MUSIC_DESTINATION)
    .gsub('{{AUDIOBOOKS_DESTINATION}}', AUDIOBOOKS_DESTINATION)
    .gsub('{{MUSIC_DIRECTORY}}', MUSIC_DIRECTORY)
    .gsub('{{AUDIOBOOKS_DIRECTORY}}', AUDIOBOOKS_DIRECTORY)

  File.write(DAP_SYNC_OUTPUT, processed_content)
  File.chmod(0o755, DAP_SYNC_OUTPUT)
rescue StandardError => e
  puts "Warning: Failed to process dap_sync template: #{e.message}"
end

get '/' do
  # Serve React app index.html
  index_path = File.join(File.dirname(__FILE__), 'public', 'index.html')
  if File.exist?(index_path)
    send_file index_path
  else
    # Fallback if React build doesn't exist yet
    content_type :html
    '<!DOCTYPE html><html><body><h1>Building React app...</h1></body></html>'
  end
rescue Errno::ENOENT
  status 404
  "File not found"
end

get '/api/albums' do
  content_type :json
  grouped = get_albums_grouped_by_artist
  audiobooks = get_audiobooks
  selection = read_sync_selection
  
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
  device_size_bytes = (DEVICE_SIZE_GB * 1024 * 1024 * 1024).to_i
  
  {
    albums_by_artist: grouped,
    albums: get_all_albums,
    audiobooks: audiobooks,
    selection: selection,
    total_size: total_size,
    total_size_formatted: format_size(total_size),
    audiobooks_total_size: audiobooks_total_size,
    audiobooks_total_size_formatted: format_size(audiobooks_total_size),
    device_size_gb: DEVICE_SIZE_GB,
    device_size_bytes: device_size_bytes,
    device_size_formatted: format_size(device_size_bytes)
  }.to_json
end

post '/api/selection' do
  content_type :json
  data = JSON.parse(request.body.read)
  
  music_mode = data['music_mode'] || data['mode'] || 'all'
  music_albums = data['music_albums'] || data['albums'] || []
  audiobooks_mode = data['audiobooks_mode'] || 'all'
  audiobooks_list = data['audiobooks'] || []
  
  # Pass relative paths - write_sync_selection will convert to full paths using MUSIC_DIRECTORY/AUDIOBOOKS_DIRECTORY
  write_sync_selection(music_mode, music_albums, audiobooks_mode, audiobooks_list)
  
  { success: true, message: "Selection saved successfully" }.to_json
end

get '/api/selection' do
  content_type :json
  read_sync_selection.to_json
end
