# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/module/delegation"

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

  class SubscribeEventObjectsTest < TestCase
    def test_subscribe_events
      events = []
      @notifier.subscribe do |event|
        events << event
      end

      ActiveSupport::Notifications.instrument("foo")
      event = events.first
      assert event, "should have an event"
      assert_operator event.allocations, :>, 0
      assert_operator event.cpu_time, :>, 0
      assert_operator event.idle_time, :>, 0
      assert_operator event.duration, :>, 0
    end

    def test_subscribe_to_events_where_payload_is_changed_during_instrumentation
      @notifier.subscribe do |event|
        assert_equal "success!", event.payload[:my_key]
      end

      ActiveSupport::Notifications.instrument("foo") do |payload|
        payload[:my_key] = "success!"
      end
    end

    def test_subscribe_to_events_can_handle_nested_hashes_in_the_paylaod
      @notifier.subscribe do |event|
        assert_equal "success!", event.payload[:some_key][:key_one]
        assert_equal "great_success!", event.payload[:some_key][:key_two]
      end

      ActiveSupport::Notifications.instrument("foo", some_key: { key_one: "success!" }) do |payload|
        payload[:some_key][:key_two] = "great_success!"
      end
    end

    def test_subscribe_via_top_level_api
      old_notifier = ActiveSupport::Notifications.notifier
      ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new

      event = nil
      ActiveSupport::Notifications.subscribe("foo") do |e|
        event = e
      end

      ActiveSupport::Notifications.instrument("foo") do
        100.times { Object.new } # allocate at least 100 objects
      end

      assert event
      assert_operator event.allocations, :>=, 100
    ensure
      ActiveSupport::Notifications.notifier = old_notifier
    end

    def test_subscribe_with_a_single_arity_lambda_listener
      event_name = nil
      listener = ->(event) do
        event_name = event.name
      end

      @notifier.subscribe(&listener)
      ActiveSupport::Notifications.instrument("event_name")

      assert_equal "event_name", event_name
    end

    def test_subscribe_with_a_single_arity_callable_listener
      event_name = nil
      listener = Class.new do
        define_method :call do |event|
          event_name = event.name
        end
      end

      @notifier.subscribe(nil, listener.new)
      ActiveSupport::Notifications.instrument("event_name")

      assert_equal "event_name", event_name
    end
  end

  class TimedAndMonotonicTimedSubscriberTest < TestCase
    def test_subscribe
      event_name = "foo"
      class_of_started = nil
      class_of_finished = nil

      ActiveSupport::Notifications.subscribe(event_name) do |name, started, finished, unique_id, data|
        class_of_started = started.class
        class_of_finished = finished.class
      end

      ActiveSupport::Notifications.instrument(event_name)

      assert_equal [Time, Time], [class_of_started, class_of_finished]
    end

    def test_monotonic_subscribe
      event_name = "foo"
      class_of_started = nil
      class_of_finished = nil

      ActiveSupport::Notifications.monotonic_subscribe(event_name) do |name, started, finished, unique_id, data|
        class_of_started = started.class
        class_of_finished = finished.class
      end

      ActiveSupport::Notifications.instrument(event_name)

      assert_equal [Float, Float], [class_of_started, class_of_finished]
    end
  end

  class SubscribedTest < TestCase
    def test_subscribed
      name     = "foo"
      name2    = name * 2
      expected = [name, name]

      events   = []
      callback = lambda { |*_| events << _.first }
      ActiveSupport::Notifications.subscribed(callback, name) do
        ActiveSupport::Notifications.instrument(name)
        ActiveSupport::Notifications.instrument(name2)
        ActiveSupport::Notifications.instrument(name)
      end
      assert_equal expected, events

      ActiveSupport::Notifications.instrument(name)
      assert_equal expected, events
    end

    def test_subscribed_all_messages
      name     = "foo"
      name2    = name * 2
      expected = [name, name2, name]

      events   = []
      callback = lambda { |*_| events << _.first }
      ActiveSupport::Notifications.subscribed(callback) do
        ActiveSupport::Notifications.instrument(name)
        ActiveSupport::Notifications.instrument(name2)
        ActiveSupport::Notifications.instrument(name)
      end
      assert_equal expected, events

      ActiveSupport::Notifications.instrument(name)
      assert_equal expected, events
    end

    def test_subscribing_to_instrumentation_while_inside_it
      # the repro requires that there are no evented subscribers for the "foo" event,
      # so we have to duplicate some of the setup code
      old_notifier = ActiveSupport::Notifications.notifier
      ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new

      ActiveSupport::Notifications.subscribe("foo", TestSubscriber.new)

      ActiveSupport::Notifications.instrument("foo") do
        ActiveSupport::Notifications.subscribe("foo") { }
      end
    ensure
      ActiveSupport::Notifications.notifier = old_notifier
    end

    def test_timed_subscribed
      event_name = "foo"
      class_of_started = nil
      class_of_finished = nil
      callback = lambda do |name, started, finished, unique_id, data|
        class_of_started = started.class
        class_of_finished = finished.class
      end

      ActiveSupport::Notifications.subscribed(callback, event_name) do
        ActiveSupport::Notifications.instrument(event_name)
      end

      ActiveSupport::Notifications.instrument(event_name)

      assert_equal [Time, Time], [class_of_started, class_of_finished]
    end

    def test_monotonic_timed_subscribed
      event_name = "foo"
      class_of_started = nil
      class_of_finished = nil
      callback = lambda do |name, started, finished, unique_id, data|
        class_of_started = started.class
        class_of_finished = finished.class
      end

      ActiveSupport::Notifications.subscribed(callback, event_name, monotonic: true) do
        ActiveSupport::Notifications.instrument(event_name)
      end

      ActiveSupport::Notifications.instrument(event_name)

      assert_equal [Float, Float], [class_of_started, class_of_finished]
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

    def test_unsubscribing_by_name_leaves_regexp_matched_subscriptions
      @matched_events = []
      @notifier.subscribe(/subscription/) { |*args| @matched_events << event(*args) }
      @notifier.publish("named.subscription", :before)
      @notifier.wait
      [@events, @named_events, @matched_events].each do |collector|
        assert_includes(collector, ["named.subscription", :before])
      end
      @notifier.unsubscribe("named.subscription")
      @notifier.publish("named.subscription", :after)
      @notifier.publish("other.subscription", :after)
      @notifier.wait
      assert_includes(@events, ["named.subscription", :after])
      assert_includes(@events, ["other.subscription", :after])
      assert_includes(@matched_events, ["other.subscription", :after])
      assert_not_includes(@matched_events, ["named.subscription", :after])
      assert_not_includes(@named_events, ["named.subscription", :after])
    end

  private
    def event(*args)
      args
    end
  end

  class TestSubscriber
    attr_reader :starts, :finishes, :publishes

    def initialize
      @starts    = []
      @finishes  = []
      @publishes = []
    end

    def start(*args);  @starts << args; end
    def finish(*args); @finishes << args; end
    def publish(*args); @publishes << args; end
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

      @notifier.subscribe("not_existent") do |*args|
        @events << ActiveSupport::Notifications::Event.new(*args)
      end

      @notifier.publish :foo
      @notifier.publish :foo
      @notifier.wait

      assert_equal [[:foo]] * 4, @events
    end

    def test_log_subscriber_with_string
      events = []
      @notifier.subscribe("1") { |*args| events << args }

      @notifier.publish "1"
      @notifier.publish "1.a"
      @notifier.publish "a.1"
      @notifier.wait

      assert_equal [["1"]], events
    end

    def test_log_subscriber_with_pattern
      events = []
      @notifier.subscribe(/\d/) { |*args| events << args }

      @notifier.publish "1"
      @notifier.publish "a.1"
      @notifier.publish "1.a"
      @notifier.wait

      assert_equal [["1"], ["a.1"], ["1.a"]], events
    end

    def test_multiple_log_subscribers
      @another = []
      @notifier.subscribe { |*args| @another << args }
      @notifier.publish :foo
      @notifier.wait

      assert_equal [[:foo]], @events
      assert_equal [[:foo]], @another
    end

    def test_publish_with_subscriber
      subscriber = TestSubscriber.new
      @notifier.subscribe nil, subscriber
      @notifier.publish :foo

      assert_equal [[:foo]], subscriber.publishes
    end

    private
      def event(*args)
        args
      end
  end

  class InstrumentationTest < TestCase
    delegate :instrument, to: ActiveSupport::Notifications

    def test_instrument_returns_block_result
      assert_equal 2, instrument(:awesome) { 1 + 1 }
    end

    def test_instrument_yields_the_payload_for_further_modification
      assert_equal 2, instrument(:awesome) { |p| p[:result] = 1 + 1 }
      assert_equal 1, @events.size
      assert_equal :awesome, @events.first.name
      assert_equal Hash[result: 2], @events.first.payload
    end

    def test_instrumenter_exposes_its_id
      assert_equal 20, ActiveSupport::Notifications.instrumenter.id.size
    end

    def test_nested_events_can_be_instrumented
      instrument(:awesome, payload: "notifications") do
        instrument(:wot, payload: "child") do
          1 + 1
        end

        assert_equal 1, @events.size
        assert_equal :wot, @events.first.name
        assert_equal Hash[payload: "child"], @events.first.payload
      end

      assert_equal 2, @events.size
      assert_equal :awesome, @events.last.name
      assert_equal Hash[payload: "notifications"], @events.last.payload
    end

    def test_instrument_publishes_when_exception_is_raised
      begin
        instrument(:awesome, payload: "notifications") do
          raise "FAIL"
        end
      rescue RuntimeError => e
        assert_equal "FAIL", e.message
      end

      assert_equal 1, @events.size
      assert_equal Hash[payload: "notifications",
        exception: ["RuntimeError", "FAIL"], exception_object: e], @events.last.payload
    end

    def test_event_is_pushed_even_without_block
      instrument(:awesome, payload: "notifications")
      assert_equal 1, @events.size
      assert_equal :awesome, @events.last.name
      assert_equal Hash[payload: "notifications"], @events.last.payload
    end
  end

  class EventTest < TestCase
    def test_events_are_initialized_with_details
      time = Time.now
      event = event(:foo, time, time + 0.01, random_id, {})

      assert_equal :foo, event.name
      assert_equal time, event.time
      assert_in_delta 10.0, event.duration, 0.00001
    end

    def test_event_cpu_time_does_not_raise_error_when_start_or_finished_not_called
      time = Time.now
      event = event(:foo, time, time + 0.01, random_id, {})

      assert_equal 0, event.cpu_time
    end

    def test_events_consumes_information_given_as_payload
      event = event(:foo, Concurrent.monotonic_time, Concurrent.monotonic_time + 1, random_id, payload: :bar)
      assert_equal Hash[payload: :bar], event.payload
    end

    def test_event_is_parent_based_on_children
      time = Concurrent.monotonic_time

      parent    = event(:foo, Concurrent.monotonic_time, Concurrent.monotonic_time + 100, random_id, {})
      child     = event(:foo, time, time + 10, random_id, {})
      not_child = event(:foo, time, time + 100, random_id, {})

      parent.children << child

      assert parent.parent_of?(child)
      assert_not child.parent_of?(parent)
      assert_not parent.parent_of?(not_child)
      assert_not not_child.parent_of?(parent)
    end

    private
      def random_id
        @random_id ||= SecureRandom.hex(10)
      end
  end
end
