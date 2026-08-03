RSpec.describe "Ledger freeze/dup/clone contract" do
  it "appends entries in order" do
    ledger = Ledger.new
    ledger.add(:a)
    ledger.add(:b)
    expect(ledger.entries).to eq([:a, :b])
  end

  it "returns itself from freeze and reports frozen? afterward" do
    ledger = Ledger.new
    expect(ledger.freeze).to equal(ledger)
    expect(ledger.frozen?).to eq(true)
  end

  it "raises FrozenError from #add once frozen" do
    ledger = Ledger.new([:a])
    ledger.freeze
    expect { ledger.add(:b) }.to raise_error(FrozenError)
  end

  it "raises FrozenError mutating the array #entries returns once frozen" do
    ledger = Ledger.new([:a])
    ledger.freeze
    expect { ledger.entries << :b }.to raise_error(FrozenError)
  end

  it "produces an unfrozen, independently addable dup even from a frozen ledger" do
    ledger = Ledger.new([:a])
    ledger.freeze
    copy = ledger.dup
    expect(copy.frozen?).to eq(false)
    copy.add(:b)
    expect(copy.entries).to eq([:a, :b])
  end

  it "produces a clone that stays frozen exactly when the original was frozen" do
    ledger = Ledger.new([:a])
    ledger.freeze
    copy = ledger.clone
    expect(copy.frozen?).to eq(true)
  end

  it "gives dup its own entries array, independent of the original" do
    ledger = Ledger.new([:a])
    copy = ledger.dup
    copy.add(:b)
    expect(ledger.entries).to eq([:a])
  end
end
