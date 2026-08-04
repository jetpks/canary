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

  private

  def initialize_copy(other)
    super
    @tracks = other.instance_variable_get(:@tracks).dup
  end
end
