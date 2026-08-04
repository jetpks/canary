RSpec.describe "Interval#overlaps?" do
  it "reports true for intervals that overlap" do
    expect(Interval.new(1, 5).overlaps?(Interval.new(4, 10))).to eq(true)
  end

  it "reports true for intervals that only touch at a single shared endpoint" do
    expect(Interval.new(1, 5).overlaps?(Interval.new(5, 10))).to eq(true)
  end

  it "reports false for intervals that do not overlap at all" do
    expect(Interval.new(1, 5).overlaps?(Interval.new(6, 10))).to eq(false)
  end

  it "reports the same answer regardless of which interval is the receiver" do
    expect(Interval.new(6, 10).overlaps?(Interval.new(1, 5))).to eq(false)
  end

  it "exposes its own start and finish via #to_a" do
    expect(Interval.new(2, 9).to_a).to eq([2, 9])
  end
end
