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

  def dup
    Playlist.new(@tracks)
  end

  def clone
    copy = Playlist.new(@tracks)
    copy.freeze if frozen?
    copy
  end
end
