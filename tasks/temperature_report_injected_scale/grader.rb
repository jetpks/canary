class FahrenheitScale
  def convert(celsius_degrees)
    (celsius_degrees * 9.0 / 5 + 32).round
  end

  def label
    "F"
  end
end

RSpec.describe "TemperatureReport injected scale" do
  it "uses Celsius by default when no scale is injected" do
    expect(TemperatureReport.new.describe(20)).to eq("20C")
  end

  it "honors an injected scale instead of the default" do
    report = TemperatureReport.new(scale: FahrenheitScale.new)
    expect(report.describe(0)).to eq("32F")
  end

  it "honors an injected scale across multiple calls" do
    report = TemperatureReport.new(scale: FahrenheitScale.new)
    expect(report.describe(100)).to eq("212F")
  end

  it "TemperatureReport::Celsius converts degrees unchanged and labels C" do
    celsius = TemperatureReport::Celsius.new
    expect(celsius.convert(37)).to eq(37)
    expect(celsius.label).to eq("C")
  end
end
