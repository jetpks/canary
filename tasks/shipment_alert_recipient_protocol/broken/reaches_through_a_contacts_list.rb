class ShipmentAlert
  def initialize(recipient)
    @recipient = recipient
  end

  def dispatch(message)
    "#{@recipient.contacts.first.email}: #{message}"
  end
end
