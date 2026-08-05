class EventBroadcaster
  def initialize
    @listeners = []
  end

  def subscribe(listener)
    @listeners << listener
  end

  def publish(event)
    @listeners.each { |listener| listener.notify(event) }
  end
end
