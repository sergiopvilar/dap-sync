class Directories
  def self.normalize_path(path)
    path.to_s.gsub(%r{//+}, '/').sub(%r{/+$}, '')
  end

  def self.calculate_directory_size(path)
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

  def self.format_size(bytes)
    return "0 B" if bytes == 0
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    exp = (Math.log(bytes) / Math.log(1024)).floor
    exp = units.length - 1 if exp >= units.length
    "#{(bytes / (1024.0 ** exp)).round(2)} #{units[exp]}"
  end
end