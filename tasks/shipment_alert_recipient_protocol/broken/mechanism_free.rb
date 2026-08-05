class ShipmentAlert
  def initialize(recipient)
    @recipient = recipient
  end

  def dispatch(message)
    "#{@recipient.address}: #{message}"
  end
end
