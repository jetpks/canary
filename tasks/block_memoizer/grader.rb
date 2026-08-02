RSpec.describe "Memoizer closures over mutable state" do
  it "returns the computed value" do
    memoized = Memoizer.wrap { 1 + 1 }
    expect(memoized.call).to eq(2)
  end

  it "only calls the underlying computation once" do
    calls = 0
    memoized = Memoizer.wrap do
      calls += 1
      calls
    end
    memoized.call
    memoized.call
    memoized.call
    expect(calls).to eq(1)
  end

  it "caches a falsy result instead of recomputing it" do
    calls = 0
    memoized = Memoizer.wrap do
      calls += 1
      nil
    end
    memoized.call
    memoized.call
    expect(calls).to eq(1)
  end

  it "passes call-time arguments through to the computation" do
    memoized = Memoizer.wrap { |a, b| a + b }
    expect(memoized.call(3, 4)).to eq(7)
  end
end
