RSpec.describe "Finder.first_matching" do
  it "finds the first n matches" do
    expect(Finder.first_matching(1..1_000_000) { |i| i.even? }.first(3)).to eq([2, 4, 6])
  end

  it "stops pulling from the source once it has enough matches" do
    calls = 0
    Finder.first_matching(1..1_000_000) do |i|
      calls += 1
      i.even?
    end.first(3)
    expect(calls).to be < 50
  end

  it "supports chaining a further filter without having committed to a fixed count ahead of time" do
    result = Finder.first_matching(1..1_000_000) { |i| i.even? }.select { |i| i > 1000 }.first(2)
    expect(result).to eq([1002, 1004])
  end
end
