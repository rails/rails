require 'abstract_unit'

# Allow LittleFanout to be cleaned.
class ActiveSupport::Notifications::LittleFanout
  def clear
    @listeners.clear
  end
end

class NotificationsEventTest < Test::Unit::TestCase
  def test_events_are_initialized_with_details
    event = event(:foo, Time.now, Time.now + 1, 1, random_id, :payload => :bar)
    assert_equal :foo, event.name
    assert_equal Hash[:payload => :bar], event.payload
  end

  def test_events_consumes_information_given_as_payload
    time = Time.now
    event = event(:foo, time, time + 0.01, 1, random_id, {})

    assert_equal Hash.new, event.payload
    assert_equal time, event.time
    assert_equal 1, event.result
    assert_equal 10.0, event.duration
  end

  def test_event_is_parent_based_on_time_frame
    time = Time.utc(2009, 01, 01, 0, 0, 1)

    parent    = event(:foo, Time.utc(2009), Time.utc(2009) + 100, nil, random_id, {})
    child     = event(:foo, time, time + 10, nil, random_id, {})
    not_child = event(:foo, time, time + 100, nil, random_id, {})

    assert parent.parent_of?(child)
    assert !child.parent_of?(parent)
    assert !parent.parent_of?(not_child)
    assert !not_child.parent_of?(parent)
  end

protected

  def random_id
    @random_id ||= ActiveSupport::SecureRandom.hex(10)
  end

  def event(*args)
    ActiveSupport::Notifications::Event.new(*args)
  end
end

class NotificationsMainTest < Test::Unit::TestCase
  def setup
    @events = []
    Thread.abort_on_exception = true
    ActiveSupport::Notifications.subscribe do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  def teardown
    Thread.abort_on_exception = false
    ActiveSupport::Notifications.queue.clear
  end

  def test_notifications_returns_action_result
    result = ActiveSupport::Notifications.instrument(:awesome, :payload => "notifications") do
      1 + 1
    end

    assert_equal 2, result
  end

  def test_events_are_published_to_a_listener
    ActiveSupport::Notifications.instrument(:awesome, :payload => "notifications") do
      1 + 1
    end

    drain

    assert_equal 1, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal Hash[:payload => "notifications"], @events.last.payload
  end

  def test_nested_events_can_be_instrumented
    ActiveSupport::Notifications.instrument(:awesome, :payload => "notifications") do
      ActiveSupport::Notifications.instrument(:wot, :payload => "child") do
        1 + 1
      end

      drain

      assert_equal 1, @events.size
      assert_equal :wot, @events.first.name
      assert_equal Hash[:payload => "child"], @events.first.payload
    end

    drain

    assert_equal 2, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal Hash[:payload => "notifications"], @events.last.payload
  end

  def test_event_is_pushed_even_if_block_fails
    ActiveSupport::Notifications.instrument(:awesome, :payload => "notifications") do
      raise "OMG"
    end rescue RuntimeError

    drain

    assert_equal 1, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal Hash[:payload => "notifications"], @events.last.payload
  end

  def test_event_is_pushed_even_without_block
    ActiveSupport::Notifications.instrument(:awesome, :payload => "notifications")
    drain

    assert_equal 1, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal Hash[:payload => "notifications"], @events.last.payload
  end

  def test_subscribed_in_a_transaction
    @another = []

    ActiveSupport::Notifications.subscribe("cache") do |*args|
      @another << ActiveSupport::Notifications::Event.new(*args)
    end

    ActiveSupport::Notifications.instrument(:cache){ 1 }
    ActiveSupport::Notifications.transaction do
      ActiveSupport::Notifications.instrument(:cache){ 1 }
    end
    ActiveSupport::Notifications.instrument(:cache){ 1 }

    drain

    assert_equal 3, @another.size
    before, during, after = @another.map {|e| e.transaction_id }
    assert_equal before, after
    assert_not_equal before, during
  end

  def test_subscriber_with_pattern
    @another = []

    ActiveSupport::Notifications.subscribe("cache") do |*args|
      @another << ActiveSupport::Notifications::Event.new(*args)
    end

    ActiveSupport::Notifications.instrument(:cache){ 1 }

    drain

    assert_equal 1, @another.size
    assert_equal :cache, @another.first.name
    assert_equal 1, @another.first.result
  end

  def test_subscriber_with_pattern_as_regexp
    @another = []
    ActiveSupport::Notifications.subscribe(/cache/) do |*args|
      @another << ActiveSupport::Notifications::Event.new(*args)
    end

    ActiveSupport::Notifications.instrument(:something){ 0 }
    ActiveSupport::Notifications.instrument(:cache){ 1 }

    drain

    assert_equal 1, @another.size
    assert_equal :cache, @another.first.name
    assert_equal 1, @another.first.result
  end

  def test_with_several_consumers_and_several_events
    @another = []
    ActiveSupport::Notifications.subscribe do |*args|
      @another << ActiveSupport::Notifications::Event.new(*args)
    end

    1.upto(100) do |i|
      ActiveSupport::Notifications.instrument(:value){ i }
    end

    drain

    assert_equal 100, @events.size
    assert_equal :value, @events.first.name
    assert_equal 1, @events.first.result
    assert_equal 100, @events.last.result

    assert_equal 100, @another.size
    assert_equal :value, @another.first.name
    assert_equal 1, @another.first.result
    assert_equal 100, @another.last.result
  end

  private
    def drain
      sleep(0.1) until ActiveSupport::Notifications.queue.drained?
    end
end
