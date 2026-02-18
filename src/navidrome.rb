require 'sqlite3'

class Navidrome
  def initialize
    @db = SQLite3::Database.new('/data/navidrome.db')
  end

  def get_song_path(id)
    @db.execute("SELECT path FROM media_file WHERE id = ?", id).flatten.first
  end
end