class MoodBoard
  def initialize(palette)
    @palette = palette
  end

  def sorted_swatches
    @palette.swatches.sort
  end

  def distinct_count
    @palette.swatches.size
  end
end
