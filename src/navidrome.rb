require 'sqlite3'

class Navidrome
  def initialize
    @db = SQLite3::Database.new('/data/navidrome.db')
  end

  def list_tables
    @db.execute("SELECT name FROM sqlite_master WHERE type='table'")
  end

  def get_playlist_name(playlist_id)
    @db.execute("SELECT name FROM playlist WHERE id = ?", playlist_id).flatten.first
  end

  def get_playlists
    @db.execute("SELECT id, name, song_count, duration, public FROM playlist").map do |row|
      {
        id: row[0],
        name: row[1],
        song_count: row[2],
        duration: row[3],
        public: row[4] == 1,
      }
    end
  end

  def get_playlist_songs(playlist_id)
    @db.execute("SELECT media_file_id FROM playlist_tracks WHERE playlist_id = ?", playlist_id).map { |row| row[0] }
  end

  def get_song_path(id)
    @db.execute("SELECT path FROM media_file WHERE id = ?", id).flatten.first
  end
end