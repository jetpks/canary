RSpec.describe "Band drives case/when and grep" do
  let(:warm) { Band.new(60, 80) }

  def against_warm(value, warm)
    case value
    when warm then :warm
    else :other
    end
  end

  def classify(value)
    cold = Band.new(0, 60)
    warm = Band.new(60, 80)
    hot = Band.new(80, 100)

    case value
    when cold then :cold
    when warm then :warm
    when hot then :hot
    else :unknown
    end
  end

  it "selects the when clause whose band matches the value" do
    expect(against_warm(70, warm)).to eq(:warm)
  end

  it "treats the minimum as inclusive" do
    expect(against_warm(60, warm)).to eq(:warm)
  end

  it "treats the maximum as exclusive" do
    expect(against_warm(80, warm)).to eq(:other)
  end

  it "checks several bands in order and falls through to else when none match" do
    expect([10, 70, 90, 120].map { |v| classify(v) }).to eq(%i[cold warm hot unknown])
  end

  it "filters an array via grep, preserving original order" do
    expect([55, 60, 65, 80, 75].grep(warm)).to eq([60, 65, 75])
  end
end
