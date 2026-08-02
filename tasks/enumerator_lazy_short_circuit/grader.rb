RSpec.describe "Finder.first_matching" do
  it "finds the first n matches" do
    expect(Finder.first_matching(1..1_000_000, 3) { |i| i.even? }).to eq([2, 4, 6])
  end

  it "stops pulling from the source once it has enough matches" do
    calls = 0
    Finder.first_matching(1..1_000_000, 3) do |i|
      calls += 1
      i.even?
    end
    expect(calls).to be < 50
  end
end
