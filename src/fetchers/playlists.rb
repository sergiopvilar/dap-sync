require_relative '../navidrome.rb'

module Fetchers
  class Playlists
    def self.all
      Navidrome.new.get_playlists.map do |playlist|
        {
          id: playlist[:id],
          name: playlist[:name],
          songCount: playlist[:song_count],
          duration: playlist[:duration],
          public: playlist[:public],
          owner: playlist[:owner]
        }
      end
    end
  end
end