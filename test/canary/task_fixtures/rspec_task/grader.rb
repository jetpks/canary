RSpec.describe "task multiplier" do
  it "multiplies two positive numbers" do
    expect(TaskMultiplier.call(3, 4)).to eq(12)
  end

  it "multiplies by zero" do
    expect(TaskMultiplier.call(5, 0)).to eq(0)
  end
end
