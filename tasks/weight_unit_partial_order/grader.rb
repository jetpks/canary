RSpec.describe "Weight partial ordering across units" do
  it "orders weights with the same unit by amount" do
    expect(Weight.new(5, :kg)).to be < Weight.new(10, :kg)
  end

  it "sorts an array of weights sharing one unit" do
    weights = [Weight.new(10, :kg), Weight.new(1, :kg), Weight.new(5, :kg)]
    expect(weights.sort.map(&:amount)).to eq([1, 5, 10])
  end

  it "treats same-unit, same-amount weights as equal" do
    expect(Weight.new(5, :kg)).to eq(Weight.new(5, :kg))
  end

  it "never treats different-unit weights as equal, even with matching amounts" do
    expect(Weight.new(5, :kg)).not_to eq(Weight.new(5, :lb))
  end

  it "raises ArgumentError comparing weights of different units" do
    expect { Weight.new(5, :kg) < Weight.new(5, :lb) }.to raise_error(ArgumentError)
  end

  it "raises ArgumentError sorting an array that mixes units" do
    expect { [Weight.new(5, :kg), Weight.new(5, :lb)].sort }.to raise_error(ArgumentError)
  end

  it "raises ArgumentError clamping against a bound of a different unit" do
    expect { Weight.new(5, :kg).clamp(Weight.new(1, :lb), Weight.new(10, :kg)) }.to raise_error(ArgumentError)
  end

  it "raises ArgumentError checking between? against bounds of a different unit" do
    expect { Weight.new(5, :kg).between?(Weight.new(1, :kg), Weight.new(10, :lb)) }.to raise_error(ArgumentError)
  end
end
