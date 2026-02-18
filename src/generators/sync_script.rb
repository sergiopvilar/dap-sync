require 'fileutils'
require_relative '../config.rb'

module Generators
  class SyncScript
    def self.generate_sync_script    
      FileUtils.mkdir_p(File.dirname(Config.dap_sync_output))
    
      template_path = File.expand_path('../../templates/dap_sync.sh', __FILE__)
      template_content = File.read(template_path)
      processed_content = template_content
        .gsub('{{SYNC_SELECTION_FILE}}', Config.sync_selection_file)
        .gsub('{{PLAYLISTS_DIR}}', Config.playlists_dir)
        .gsub('{{MUSIC_DESTINATION}}', Config.music_destination)
        .gsub('{{AUDIOBOOKS_DESTINATION}}', Config.audiobooks_destination)
        .gsub('{{MUSIC_DIRECTORY}}', Config.music_source)
        .gsub('{{AUDIOBOOKS_DIRECTORY}}', Config.audiobooks_source)
        .gsub('{{PLAYLIST_DESTINATION}}', Config.playlist_destination)
    
      File.write(Config.dap_sync_output, processed_content)
      File.chmod(0o755, Config.dap_sync_output)
    end
  end
end