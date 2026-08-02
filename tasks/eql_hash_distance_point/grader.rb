RSpec.describe "Point comparable + hash contract" do
  it "orders points by distance from the origin, not by a single coordinate" do
    expect(Point.new(5, 0)).to be < Point.new(1, 10)
  end

  it "sorts a mixed array by distance" do
    points = [Point.new(3, 4), Point.new(0, 1), Point.new(1, 10)]
    distances = points.sort.map { |p| p.distance.round(2) }
    expect(distances).to eq([1.0, 5.0, 10.05])
  end

  it "treats two equal-valued points as the same Hash key" do
    tally = Hash.new(0)
    tally[Point.new(2, 2)] += 1
    tally[Point.new(2, 2)] += 1
    expect(tally.size).to eq(1)
    expect(tally.values.first).to eq(2)
  end

  it "dedupes equal-valued points with uniq" do
    points = [Point.new(1, 1), Point.new(1, 1), Point.new(2, 2)]
    expect(points.uniq.size).to eq(2)
  end
end
