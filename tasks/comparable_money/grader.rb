RSpec.describe "Money comparable protocol" do
  it "orders small values correctly" do
    expect(Money.new(1)).to be < Money.new(2)
  end

  it "orders values that would break under lexical string comparison" do
    expect(Money.new(9)).to be < Money.new(10)
  end

  it "reports equality for equal cents" do
    expect(Money.new(5)).to eq(Money.new(5))
  end

  it "sorts a mixed array into ascending order" do
    values = [Money.new(30), Money.new(5), Money.new(100)]
    expect(values.sort.map(&:cents)).to eq([5, 30, 100])
  end

  it "clamps a value into a range" do
    expect(Money.new(500).clamp(Money.new(0), Money.new(100)).cents).to eq(100)
  end

  it "supports the full Comparable operator set derived from <=>" do
    expect(Money.new(10)).to be > Money.new(9)
    expect(Money.new(9)).to be <= Money.new(9)
    expect(Money.new(10)).to be >= Money.new(9)
  end

  it "reports whether a value falls between two others" do
    expect(Money.new(50).between?(Money.new(0), Money.new(100))).to eq(true)
    expect(Money.new(150).between?(Money.new(0), Money.new(100))).to eq(false)
  end
end
