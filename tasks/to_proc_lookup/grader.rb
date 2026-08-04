RSpec.describe "Lookup usable directly and via &" do
  let(:lookup) { Lookup.new(1 => "one", 2 => "two", 3 => "three") }

  it "calls directly, returning the mapped value" do
    expect(lookup.call(2)).to eq("two")
  end

  it "raises KeyError for a key with no mapping" do
    expect { lookup.call(9) }.to raise_error(KeyError)
  end

  it "works as a block via & inside map, in order" do
    expect([1, 2, 3].map(&lookup)).to eq(%w[one two three])
  end

  it "works as a block via & inside sort_by, ordering by the mapped value" do
    expect([3, 1, 2].sort_by(&lookup)).to eq([1, 3, 2])
  end
end
