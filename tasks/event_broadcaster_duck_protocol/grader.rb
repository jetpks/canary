class PlainListener
  attr_reader :events

  def initialize
    @events = []
  end

  def notify(event)
    @events << event
  end
end

RecordingListener = Struct.new(:events) do
  def notify(event)
    events << event
  end
end

class EventBroadcasterGraderTest < Minitest::Test
  def test_notifies_a_struct_based_listener_with_the_published_event
    listener = RecordingListener.new([])
    broadcaster = EventBroadcaster.new
    broadcaster.subscribe(listener)

    broadcaster.publish(:tick)

    assert_equal [:tick], listener.events
  end

  def test_notifies_a_plain_object_listener_that_only_implements_notify
    listener = PlainListener.new
    broadcaster = EventBroadcaster.new
    broadcaster.subscribe(listener)

    broadcaster.publish(:tick)

    assert_equal [:tick], listener.events
  end

  def test_notifies_listeners_in_subscription_order
    log = []
    first = Object.new
    first.define_singleton_method(:notify) { |event| log << [:first, event] }
    second = Object.new
    second.define_singleton_method(:notify) { |event| log << [:second, event] }

    broadcaster = EventBroadcaster.new
    broadcaster.subscribe(first)
    broadcaster.subscribe(second)

    broadcaster.publish(:go)

    assert_equal [[:first, :go], [:second, :go]], log
  end

  def test_subscribing_the_same_listener_twice_notifies_it_twice
    listener = PlainListener.new
    broadcaster = EventBroadcaster.new
    broadcaster.subscribe(listener)
    broadcaster.subscribe(listener)

    broadcaster.publish(:tick)

    assert_equal [:tick, :tick], listener.events
  end

  def test_publish_returns_the_count_of_notify_calls_made
    broadcaster = EventBroadcaster.new
    broadcaster.subscribe(PlainListener.new)
    broadcaster.subscribe(PlainListener.new)
    broadcaster.subscribe(PlainListener.new)

    assert_equal 3, broadcaster.publish(:tick)
  end
end
