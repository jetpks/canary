class NearestDollar
  def round(amount)
    amount.round
  end
end

RSpec.describe "ExpenseTracker injected rounding" do
  it "accumulates rounded amounts under the default rounding" do
    tracker = ExpenseTracker.new
    tracker.record(19.994)
    tracker.record(0.006)

    expect(tracker.total).to be_within(0.001).of(20.0)
  end

  it "honors an injected rounding collaborator instead of the default" do
    tracker = ExpenseTracker.new(rounding: NearestDollar.new)
    tracker.record(2.6)
    tracker.record(1.4)

    expect(tracker.total).to eq(4)
  end

  it "keeps a dup's recording independent of the original's, in both directions" do
    original = ExpenseTracker.new(rounding: NearestDollar.new)
    original.record(2.6)
    copy = original.dup

    copy.record(10.4)
    expect(original.total).to eq(3)
    expect(copy.total).to eq(13)

    original.record(5.2)
    expect(original.total).to eq(8)
    expect(copy.total).to eq(13)
  end

  it "keeps a dup rounding through the original's injected collaborator, not a fresh default" do
    original = ExpenseTracker.new(rounding: NearestDollar.new)
    copy = original.dup

    copy.record(2.6)

    expect(copy.total).to eq(3)
  end

  it "a fresh dup starts with the same total as the original at the moment of copying" do
    original = ExpenseTracker.new
    original.record(2.5)
    copy = original.dup

    expect(copy.total).to be_within(0.001).of(original.total)
  end
end
