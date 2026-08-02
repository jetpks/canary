RSpec.describe "other matchers" do
  it "uses include" do
    expect([1, 2, 3]).to include(2)
  end

  it "uses a failing match with a mock" do
    dbl = double("thing", foo: 1)
    expect(dbl.foo).to eq(2)
  end
end
