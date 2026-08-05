class ReadingCircle
  def initialize(directory)
    @directory = directory
  end

  def roster_size
    count = 0
    @directory.members.each { count += 1 }
    count
  end

  def greeting
    names = []
    @directory.members.each { |name| names << name }
    names.join(",")
  end
end
