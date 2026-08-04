class Playlist
  def initialize(tracks = [])
    @tracks = tracks.dup
  end

  def add(track)
    @tracks << track
    self
  end

  def tracks
    @tracks
  end
end
