class CustomerRecord
  Contact = Struct.new(:email)

  def initialize(email)
    @contacts = [Contact.new(email)]
  end

  attr_reader :contacts

  def alert_address
    @contacts.first.email
  end
end

class StrictRecipient
  def initialize(email)
    @email = email
  end

  def alert_address
    @email
  end

  def method_missing(name, *)
    raise NoMethodError, "ShipmentAlert must not call ##{name} on its recipient"
  end

  def respond_to_missing?(name, include_private = false)
    false
  end
end

RSpec.describe "ShipmentAlert recipient protocol" do
  it "dispatches using a recipient whose alert_address happens to be backed by a contacts list" do
    alert = ShipmentAlert.new(CustomerRecord.new("ops@example.com"))
    expect(alert.dispatch("delayed")).to eq("ops@example.com: delayed")
  end

  it "dispatches using a recipient with a different internal shape, calling only alert_address" do
    alert = ShipmentAlert.new(StrictRecipient.new("ops@example.com"))
    expect(alert.dispatch("delayed")).to eq("ops@example.com: delayed")
  end

  it "formats the address, a colon, a space, then the message" do
    alert = ShipmentAlert.new(StrictRecipient.new("a@b.com"))
    expect(alert.dispatch("out for delivery")).to eq("a@b.com: out for delivery")
  end

  it "never calls any method on recipient other than alert_address, even across repeated dispatches" do
    recipient = StrictRecipient.new("ops@example.com")
    alert = ShipmentAlert.new(recipient)

    expect(alert.dispatch("first")).to eq("ops@example.com: first")
    expect(alert.dispatch("second")).to eq("ops@example.com: second")
  end
end
