class EventBroadcaster
  def initialize
    @listeners = []
  end

  def subscribe(listener)
    @listeners << listener unless @listeners.include?(listener)
  end

  def publish(event)
    @listeners.each { |listener| listener.notify(event) }
    @listeners.size
  end
end
