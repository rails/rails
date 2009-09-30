require 'abstract_unit'

# Allow LittleFanout to be cleaned.
class ActiveSupport::Orchestra::LittleFanout
  def clear
    @listeners.clear
  end
end

class OrchestraEventTest < Test::Unit::TestCase
  def setup
    @parent = ActiveSupport::Orchestra::Event.new(:parent)
  end

  def test_initialization_with_name_and_parent_and_payload
    event = ActiveSupport::Orchestra::Event.new(:awesome, @parent, :payload => "orchestra")
    assert_equal(:awesome, event.name)
    assert_equal(@parent, event.parent)
    assert_equal({ :payload => "orchestra" }, event.payload)
  end

  def test_thread_id_is_set_on_initialization
    event = ActiveSupport::Orchestra::Event.new(:awesome)
    assert_equal Thread.current.object_id, event.thread_id
  end

  def test_current_time_is_set_on_initialization
    previous_time = Time.now.utc
    event = ActiveSupport::Orchestra::Event.new(:awesome)
    assert_kind_of Time, event.time
    assert event.time.to_f >= previous_time.to_f
  end
 
  def test_duration_is_set_when_event_finishes
    event = ActiveSupport::Orchestra::Event.new(:awesome)
    sleep(0.1)
    event.finish!
    assert_in_delta 100, event.duration, 30
  end
end

class OrchestraMainTest < Test::Unit::TestCase
  def setup
    @events = []
    ActiveSupport::Orchestra.subscribe { |event| @events << event }
  end

  def teardown
    ActiveSupport::Orchestra.queue.clear
  end

  def test_orchestra_allows_any_action_to_be_instrumented
    event = ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      sleep(0.1)
    end

    assert_equal :awesome, event.name
    assert_equal "orchestra", event.payload
    assert_in_delta 100, event.duration, 30
  end

  def test_block_result_is_stored
    event = ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      1 + 1
    end

    assert_equal 2, event.result
  end

  def test_events_are_published_to_a_listener
    event = ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      1 + 1
    end

    assert_equal 1, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal "orchestra", @events.last.payload
  end

  def test_nested_events_can_be_instrumented
    ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      ActiveSupport::Orchestra.instrument(:wot, "child") do
        sleep(0.1)
      end

      assert_equal 1, @events.size
      assert_equal :wot, @events.first.name
      assert_equal "child", @events.first.payload

      assert_nil @events.first.parent.duration
      assert_in_delta 100, @events.first.duration, 30
    end

    assert_equal 2, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal "orchestra", @events.last.payload
    assert_in_delta 100, @events.first.parent.duration, 30
  end

  def test_event_is_pushed_even_if_block_fails
    ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      raise "OMG"
    end rescue RuntimeError

    assert_equal 1, @events.size
    assert_equal :awesome, @events.last.name
    assert_equal "orchestra", @events.last.payload
  end

  def test_subscriber_with_pattern
    @another = []
    ActiveSupport::Orchestra.subscribe(/cache/) { |event| @another << event }

    ActiveSupport::Orchestra.instrument(:something){ 0 }
    ActiveSupport::Orchestra.instrument(:cache){ 10 }

    sleep 0.1

    assert_equal 1, @another.size
    assert_equal :cache, @another.first.name
    assert_equal 10, @another.first.result
  end

  def test_with_several_consumers_and_several_events
    @another = []
    ActiveSupport::Orchestra.subscribe { |event| @another << event }

    1.upto(100) do |i|
      ActiveSupport::Orchestra.instrument(:value){ i }
    end

    sleep 0.1

    assert_equal 100, @events.size
    assert_equal :value, @events.first.name
    assert_equal 1, @events.first.result
    assert_equal 100, @events.last.result

    assert_equal 100, @another.size
    assert_equal :value, @another.first.name
    assert_equal 1, @another.first.result
    assert_equal 100, @another.last.result
  end
end
