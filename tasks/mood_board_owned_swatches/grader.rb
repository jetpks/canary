class FreshArrayPalette
  def initialize(hexes)
    @hexes = hexes
  end

  def swatches
    @hexes.dup
  end
end

class FrozenSingletonPalette
  def initialize(hexes)
    @hexes = hexes.freeze
  end

  def swatches
    @hexes
  end
end

RSpec.describe "MoodBoard owned swatches" do
  it "sorts swatches from a palette that returns a fresh array each call" do
    board = MoodBoard.new(FreshArrayPalette.new(["#3fa", "#0aa", "#3fa"]))

    expect(board.sorted_swatches).to eq(["#0aa", "#3fa", "#3fa"])
  end

  it "counts distinct swatches from a palette that returns a fresh array each call" do
    board = MoodBoard.new(FreshArrayPalette.new(["#3fa", "#0aa", "#3fa"]))

    expect(board.distinct_count).to eq(2)
  end

  it "sorts swatches from a palette that returns the same frozen array every call" do
    board = MoodBoard.new(FrozenSingletonPalette.new(["#3fa", "#0aa", "#3fa"]))

    expect(board.sorted_swatches).to eq(["#0aa", "#3fa", "#3fa"])
  end

  it "counts distinct swatches from a palette that returns the same frozen array every call" do
    board = MoodBoard.new(FrozenSingletonPalette.new(["#3fa", "#0aa", "#3fa"]))

    expect(board.distinct_count).to eq(2)
  end
end
