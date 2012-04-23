require 'abstract_unit'
require 'active_support/core_ext/module/delegation'

module Notifications
  class TestCase < ActiveSupport::TestCase
    def setup
      @old_notifier = ActiveSupport::Notifications.notifier
      @notifier = ActiveSupport::Notifications::Fanout.new
      ActiveSupport::Notifications.notifier = @notifier
      @events = []
      @named_events = []
      @subscription = @notifier.subscribe { |*args| @events << event(*args) }
      @named_subscription = @notifier.subscribe("named.subscription") { |*args| @named_events << event(*args) }
    end

    def teardown
      ActiveSupport::Notifications.notifier = @old_notifier
    end

  private

    def event(*args)
      ActiveSupport::Notifications::Event.new(*args)
    end
  end

  class SubscribedTest < TestCase
    def test_subscribed
      name     = "foo"
      name2    = name * 2
      expected = [name, name]

      events   = []
      callback = lambda {|*_| events << _.first}
      ActiveSupport::Notifications.subscribed(callback, name) do
        ActiveSupport::Notifications.instrument(name)
        ActiveSupport::Notifications.instrument(name2)
        ActiveSupport::Notifications.instrument(name)
      end
      assert_equal expected, events

      ActiveSupport::Notifications.instrument(name)
      assert_equal expected, events
    end
  end

  class UnsubscribeTest < TestCase
    def test_unsubscribing_removes_a_subscription
      @notifier.publish :foo
      @notifier.wait
      assert_equal [[:foo]], @events
      @notifier.unsubscribe(@subscription)
      @notifier.publish :foo
      @notifier.wait
      assert_equal [[:foo]], @events
    end

    def test_unsubscribing_by_name_removes_a_subscription
      @notifier.publish "named.subscription", :foo
      @notifier.wait
      assert_equal [["named.subscription", :foo]], @named_events
      @notifier.unsubscribe("named.subscription")
      @notifier.publish "named.subscription", :foo
      @notifier.wait
      assert_equal [["named.subscription", :foo]], @named_events
    end

    def test_unsubscribing_by_name_leaves_the_other_subscriptions
      @notifier.publish "named.subscription", :foo
      @notifier.wait
      assert_equal [["named.subscription", :foo]], @events
      @notifier.unsubscribe("named.subscription")
      @notifier.publish "named.subscription", :foo
      @notifier.wait
      assert_equal [["named.subscription", :foo], ["named.subscription", :foo]], @events
    end

  private
    def event(*args)
      args
    end
  end

  class SyncPubSubTest < TestCase
    def test_events_are_published_to_a_listener
      @notifier.publish :foo
      @notifier.wait
      assert_equal [[:foo]], @events
    end

    def test_publishing_multiple_times_works
      @notifier.publish :foo
      @notifier.publish :foo
      @notifier.wait
      assert_equal [[:foo], [:foo]], @events
    end

    def test_publishing_after_a_new_subscribe_works
      @notifier.publish :foo
      @notifier.publish :foo

      @notifier.subscribe("not_existant") do |*args|
        @events << ActiveSupport::Notifications::Event.new(*args)
      end

      @notifier.publish :foo
      @notifier.publish :foo
      @notifier.wait

      assert_equal [[:foo]] * 4, @events
    end

    def test_log_subscriber_with_string
      events = []
      @notifier.subscribe('1') { |*args| events << args }

      @notifier.publish '1'
      @notifier.publish '1.a'
      @notifier.publish 'a.1'
      @notifier.wait

      assert_equal [['1']], events
    end

    def test_log_subscriber_with_pattern
      events = []
      @notifier.subscribe(/\d/) { |*args| events << args }

      @notifier.publish '1'
      @notifier.publish 'a.1'
      @notifier.publish '1.a'
      @notifier.wait

      assert_equal [['1'], ['a.1'], ['1.a']], events
    end

    def test_multiple_log_subscribers
      @another = []
      @notifier.subscribe { |*args| @another << args }
      @notifier.publish :foo
      @notifier.wait

      assert_equal [[:foo]], @events
      assert_equal [[:foo]], @another
    end

    private
      def event(*args)
        args
      end
  end

  class InstrumentationTest < TestCase
    delegate :instrument, :to => ActiveSupport::Notifications

    def test_instrument_returns_block_result
      assert_equal 2, instrument(:awesome) { 1 + 1 }
    end

    def test_instrument_yields_the_paylod_for_further_modification
      assert_equal 2, instrument(:awesome) { |p| p[:result] = 1 + 1 }
      assert_equal 1, @events.size
      assert_equal :awesome, @events.first.name
      assert_equal 2, @events.first.payload[:result]
    end

    def test_instrumenter_exposes_its_id
      assert_equal 20, ActiveSupport::Notifications.instrumenter.id.size
    end

    def test_nested_events_can_be_instrumented
      instrument(:awesome, :payload => "notifications") do
        instrument(:wot, :payload => "child") do
          1 + 1
        end

        assert_equal 1, @events.size
        assert_equal :wot, @events.first.name
        assert_equal "child", @events.first.payload[:payload]
      end

      assert_equal 2, @events.size
      assert_equal :awesome, @events.last.name
      assert_equal "notifications", @events.last.payload[:payload]
    end

    def test_instrument_publishes_when_exception_is_raised
      begin
        instrument(:awesome, :payload => "notifications") do
          raise "FAIL"
        end
      rescue RuntimeError => e
        assert_equal "FAIL", e.message
      end

      assert_equal 1, @events.size
      assert_equal "notifications", @events.last.payload[:payload]
      assert_equal ["RuntimeError", "FAIL"], @events.last.payload[:exception]
    end

    def test_event_is_pushed_even_without_block
      instrument(:awesome, :payload => "notifications")
      assert_equal 1, @events.size
      assert_equal :awesome, @events.last.name
      assert_equal "notifications", @events.last.payload[:payload]
    end

    def test_distinguish_between_siblings_and_children_with_low_clock_resolution
      # In some virtualized non-realtime systems, clock resolution can
      # degrade. We simulate this by returning the same time for the
      # duration of the test.
      Time.stubs(:now).returns(Time.utc(2009, 01, 01, 0, 0, 1))

      instrument(:dad) do
        instrument(:child) do
          instrument(:grand_child) do
          end
        end
        instrument(:sibling) do
        end
      end

      assert_equal 4, @events.size
      assert_equal([:grand_child, :child, :sibling, :dad],
                   @events.map(&:name))
      assert(@events[1].parent_of?(@events[0]),
             "#{@events[1].name} should be parent of #{@events[0].name}")
      assert(@events[3].parent_of?(@events[1]),
             "#{@events[3].name} should be parent of #{@events[1].name}")
      assert(!@events[1].parent_of?(@events[2]),
             "#{@events[1].name} should not be parent of #{@events[2].name}")
      assert(!@events.first.parent_of?(@events.last),
             "#{@events[0].name} should not be parent of #{@events[3].name}")
    end
  end

  class EventTest < TestCase
    def test_events_are_initialized_with_details
      time = Time.now
      event = event(:foo, time, time + 0.01, random_id, {})

      assert_equal    :foo, event.name
      assert_equal    time, event.time
      assert_in_delta 10.0, event.duration, 0.00001
    end

    def test_events_consumes_information_given_as_payload
      event = event(:foo, Time.now, Time.now + 1, random_id, :payload => :bar)
      assert_equal :bar, event.payload[:payload]
    end

    def test_event_is_parent_based_on_time_frame_and_entry_index
      time = Time.utc(2009, 01, 01, 0, 0, 1)

      parent    = event(:foo, Time.utc(2009), Time.utc(2009) + 100, random_id,
                        {:entry_index => 0, :exit_index => 2})
      child     = event(:foo, time, time + 10, random_id,
                        {:entry_index => 1, :exit_index => 0})
      not_child = event(:foo, time, time + 100, random_id,
                        {:entry_index => 2, :exit_index => 1})

      assert parent.parent_of?(child)
      assert !child.parent_of?(parent)
      assert !parent.parent_of?(not_child)
      assert !not_child.parent_of?(parent)
    end

    protected
      def random_id
        @random_id ||= SecureRandom.hex(10)
      end
  end
end
