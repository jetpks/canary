class ReadingCircle
  def initialize(directory)
    @directory = directory
  end

  def roster_size
    @directory.members.size
  end

  def greeting
    @directory.members.join(", ")
  end
end
