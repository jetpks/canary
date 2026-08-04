RSpec.describe "Counter dup/clone step isolation" do
  it "starts at zero and bumps by the default step" do
    counter = Counter.new
    counter.bump
    counter.bump
    expect(counter.value).to eq(2)
  end

  it "returns itself from bump" do
    counter = Counter.new
    expect(counter.bump).to equal(counter)
  end

  it "applies with_step's step only inside the block, then restores the previous step" do
    counter = Counter.new
    counter.with_step(5) { counter.bump }
    counter.bump
    expect(counter.value).to eq(6)
  end

  it "gives a dup its own value at the moment of copying, independent afterward" do
    original = Counter.new
    original.bump
    original.bump
    copy = original.dup
    expect(copy.value).to eq(2)
    copy.bump
    expect(copy.value).to eq(3)
    expect(original.value).to eq(2)
  end

  it "never lets a dup's with_step override affect the original's step" do
    original = Counter.new
    copy = original.dup
    copy.with_step(10) do
      copy.bump
      original.bump
    end
    expect(copy.value).to eq(10)
    expect(original.value).to eq(1)
  end

  it "never lets a clone's with_step override affect the original's step" do
    original = Counter.new
    copy = original.clone
    copy.with_step(10) do
      copy.bump
      original.bump
    end
    expect(copy.value).to eq(10)
    expect(original.value).to eq(1)
  end
end
