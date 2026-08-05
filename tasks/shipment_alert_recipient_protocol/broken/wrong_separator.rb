class ShipmentAlert
  def initialize(recipient)
    @recipient = recipient
  end

  def dispatch(message)
    "#{@recipient.alert_address} - #{message}"
  end
end
