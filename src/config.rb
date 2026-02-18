require 'yaml'
require 'erb'
require_relative './directories.rb'

class Config
  CONFIG_PATH = File.expand_path('../../config.yaml', __FILE__)

  def initialize
    raw = File.read(CONFIG_PATH)
    @config = YAML.safe_load(ERB.new(raw).result) || {}
  end

  def self.internal_data_path
    "/data"
  end

  def self.sync_selection_file
    Directories.normalize_path("#{Config.data_path}/sync_selection.txt")
  end

  def self.internal_navidrome_database
    Directories.normalize_path("#{Config.internal_data_path}/navidrome.db")
  end

  def self.internal_sync_selection_file
    Directories.normalize_path("#{Config.internal_data_path}/sync_selection.txt")
  end

  def self.playlists_dir
    Directories.normalize_path("#{Config.data_path}/Playlists")
  end

  def self.dap_sync_output
    Directories.normalize_path("#{Config.internal_data_path}/dap_sync.sh")
  end

  def [](key)
    @config[key.to_s]
  end

  def key?(key)
    @config.key?(key.to_s)
  end

  def self.method_missing(method_name, *args, &block)
    key = method_name.to_s
    return super if key.end_with?('?', '!') || !args.empty? || block
    instance.__send__(:[], key)
  end

  def self.respond_to_missing?(method_name, include_private = false)
    key = method_name.to_s
    !key.end_with?('?', '!') && instance.key?(key)
  end

  def self.instance
    @instance ||= new
  end
  private_class_method :new
end