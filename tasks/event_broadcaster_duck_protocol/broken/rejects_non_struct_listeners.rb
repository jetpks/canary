class EventBroadcaster
  def initialize
    @listeners = []
  end

  def subscribe(listener)
    raise TypeError, "listener must be a Struct-based value object" unless listener.is_a?(Struct) && listener.respond_to?(:notify)

    @listeners << listener
  end

  def publish(event)
    @listeners.each { |listener| listener.notify(event) }
    @listeners.size
  end
end
