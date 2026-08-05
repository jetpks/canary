class Delivery
  def initialize
    @manifest = {}
  end

  def log(tracking_id, status)
    @manifest[tracking_id] = status
  end

  def route(tracking_id)
    status = @manifest[tracking_id]
    return yield(tracking_id, status) if block_given?

    status
  end
end

class AuditedDelivery < Delivery
  def initialize
    super
    @audit_trail = []
  end

  attr_reader :audit_trail

  def route(tracking_id)
    super(tracking_id) do |id, status|
      @audit_trail << [id, status]
      if block_given?
        yield(status, id)
      else
        status
      end
    end
  end
end
