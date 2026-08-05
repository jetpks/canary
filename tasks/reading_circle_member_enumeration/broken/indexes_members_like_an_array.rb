class ReadingCircle
  def initialize(directory)
    @directory = directory
  end

  def roster_size
    @directory.members.length
  end

  def greeting
    members = @directory.members
    (0...members.length).map { |i| members[i] }.join(", ")
  end
end
