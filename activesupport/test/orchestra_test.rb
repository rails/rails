require 'abstract_unit'

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
    @listener = []
    ActiveSupport::Orchestra.register @listener
  end

  def teardown
    ActiveSupport::Orchestra.unregister @listener
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

    assert_equal 1, @listener.size
    assert_equal :awesome, @listener.last.name
    assert_equal "orchestra", @listener.last.payload
  end

  def test_nested_events_can_be_instrumented
    ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      ActiveSupport::Orchestra.instrument(:wot, "child") do
        sleep(0.1)
      end

      assert_equal 1, @listener.size
      assert_equal :wot, @listener.first.name
      assert_equal "child", @listener.first.payload

      assert_nil @listener.first.parent.duration
      assert_in_delta 100, @listener.first.duration, 30
    end

    assert_equal 2, @listener.size
    assert_equal :awesome, @listener.last.name
    assert_equal "orchestra", @listener.last.payload
    assert_in_delta 100, @listener.first.parent.duration, 30
  end

  def test_event_is_pushed_even_if_block_fails
    ActiveSupport::Orchestra.instrument(:awesome, "orchestra") do
      raise "OMG"
    end rescue RuntimeError

    assert_equal 1, @listener.size
    assert_equal :awesome, @listener.last.name
    assert_equal "orchestra", @listener.last.payload
  end
end

class OrchestraListenerTest < Test::Unit::TestCase
  class MyListener < ActiveSupport::Orchestra::Listener
    attr_reader :consumed

    def consume(event)
      @consumed ||= []
      @consumed << event
    end
  end

  def setup
    @listener = MyListener.new
    ActiveSupport::Orchestra.register @listener
  end

  def teardown
    ActiveSupport::Orchestra.unregister @listener
  end

  def test_thread_is_exposed_by_listener
    assert_kind_of Thread, @listener.thread
  end

  def test_event_is_consumed_when_an_action_is_instrumented
    ActiveSupport::Orchestra.instrument(:sum) do
      1 + 1
    end
    sleep 0.1
    assert_equal 1, @listener.consumed.size
    assert_equal :sum, @listener.consumed.first.name
    assert_equal 2, @listener.consumed.first.result
  end

  def test_with_sevaral_consumers_and_several_events
    @another = MyListener.new
    ActiveSupport::Orchestra.register @another

    1.upto(100) do |i|
      ActiveSupport::Orchestra.instrument(:value) do
        i
      end
    end

    sleep 0.1

    assert_equal 100, @listener.consumed.size
    assert_equal :value, @listener.consumed.first.name
    assert_equal 1, @listener.consumed.first.result
    assert_equal 100, @listener.consumed.last.result

    assert_equal 100, @another.consumed.size
    assert_equal :value, @another.consumed.first.name
    assert_equal 1, @another.consumed.first.result
    assert_equal 100, @another.consumed.last.result
  ensure
    ActiveSupport::Orchestra.unregister @another
  end
end
