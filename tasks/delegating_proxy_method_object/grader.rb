RSpec.describe "Proxy delegation and method lookup" do
  it "forwards a call with no arguments to the target" do
    expect(Proxy.new("hello").upcase).to eq("HELLO")
  end

  it "forwards a call with an argument to the target" do
    expect(Proxy.new("hello").start_with?("he")).to eq(true)
  end

  it "reports respond_to? true for a method the target supports" do
    expect(Proxy.new("hello").respond_to?(:upcase)).to eq(true)
  end

  it "reports respond_to? false for a method neither the target nor the proxy supports" do
    expect(Proxy.new("hello").respond_to?(:not_a_real_method)).to eq(false)
  end

  it "returns a working Method object for a forwarded method" do
    method_object = Proxy.new("hello").method(:upcase)
    expect(method_object.call).to eq("HELLO")
  end

  it "raises NameError retrieving a Method object for an unsupported name" do
    expect { Proxy.new("hello").method(:not_a_real_method) }.to raise_error(NameError)
  end

  it "raises NoMethodError calling an unsupported method directly" do
    expect { Proxy.new("hello").not_a_real_method }.to raise_error(NoMethodError)
  end
end
