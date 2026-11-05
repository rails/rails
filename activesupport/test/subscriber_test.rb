# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/subscriber"

class TestSubscriber < ActiveSupport::Subscriber
  cattr_reader :events

  def self.clear
    @@events = []
  end

  def open_party(event)
    events << event
  end

  def another_open_party(event)
    events << event
  end

  private
    def private_party(event)
      events << event
    end
end

class PartySubscriber < TestSubscriber
  def another_open_party(event)
    event.payload["processing_class"] = self.class
    events << event
  end
end

# Monkey patch subscriber to test that only one subscriber per method is added.
class TestSubscriber
  remove_method :open_party
  def open_party(event) # rubocop:disable Lint/DuplicateMethods
    events << event
  end
end

class SubscriberTest < ActiveSupport::TestCase
  def setup
    TestSubscriber.clear
  end

  def test_attaches_subscribers
    TestSubscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal "open_party.doodle", TestSubscriber.events.first.name
  ensure
    TestSubscriber.detach_from :doodle
  end

  def test_attaches_subscribers_with_inherit_all_option
    PartySubscriber.attach_to :doodle, inherit_all: true

    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal "open_party.doodle", PartySubscriber.events.first.name
  ensure
    PartySubscriber.detach_from :doodle
  end

  def test_attaches_subscribers_with_inherit_all_option_replaces_original_behavior
    PartySubscriber.attach_to :doodle, inherit_all: true

    ActiveSupport::Notifications.instrument("another_open_party.doodle")

    assert_equal 1, PartySubscriber.events.size

    event = PartySubscriber.events.first
    assert_equal "another_open_party.doodle", event.name
    assert_equal PartySubscriber, event.payload.fetch("processing_class")
  ensure
    PartySubscriber.detach_from :doodle
  end

  def test_attaches_only_one_subscriber
    TestSubscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal 1, TestSubscriber.events.size
  ensure
    TestSubscriber.detach_from :doodle
  end

  def test_does_not_attach_private_methods
    TestSubscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("private_party.doodle")

    assert_equal [], TestSubscriber.events
  ensure
    TestSubscriber.detach_from :doodle
  end

  def test_detaches_subscribers
    TestSubscriber.attach_to :doodle
    TestSubscriber.detach_from :doodle

    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal [], TestSubscriber.events
  end

  def test_detaches_subscribers_from_inherited_methods
    PartySubscriber.attach_to :doodle
    PartySubscriber.detach_from :doodle

    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal [], TestSubscriber.events
  end

  def test_supports_publish_event
    TestSubscriber.attach_to :doodle

    original_event = ActiveSupport::Notifications::Event.new("open_party.doodle", Time.at(0), Time.at(10), "id", { foo: "bar" })

    ActiveSupport::Notifications.publish_event(original_event)

    assert_equal original_event, TestSubscriber.events.first
  ensure
    TestSubscriber.detach_from :doodle
  end

  def test_publish_event_preserve_units
    event = ActiveSupport::Notifications::Event.new("publish_event.test", nil, nil, 42, {})
    event.record { sleep 0.1 }

    computed_duration = nil
    callback = -> (_, start, finish, _, _) { computed_duration = finish - start }

    ActiveSupport::Notifications.subscribed(callback, "publish_event.test") do
      ActiveSupport::Notifications.publish_event(event)
    end

    # Event#duration is in milliseconds, start and finish in seconds
    assert_in_delta event.duration / 1_000.0, computed_duration, 0.05

    ActiveSupport::Notifications.subscribed(callback, "publish_event.test", monotonic: true) do
      ActiveSupport::Notifications.publish_event(event)
    end

    assert_in_delta event.duration / 1_000.0, computed_duration, 0.05
  end

  def test_dispatches_to_handlers_named_like_internal_state
    handled = []
    subscriber = Class.new(ActiveSupport::Subscriber) do
      define_method(:event_method_names) { |event| handled << [:event_method_names, event.name] }
      define_method(:open_party) { |event| handled << [:open_party, event.name] }
    end
    subscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("event_method_names.doodle")
    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal [[:event_method_names, "event_method_names.doodle"], [:open_party, "open_party.doodle"]], handled
  ensure
    subscriber.detach_from :doodle
  end

  def test_dispatches_on_the_event_name_before_its_first_dot
    handled = []
    subscriber = Class.new(ActiveSupport::Subscriber) do
      define_method(:open) { |event| handled << [:open, event.name] }
      define_method(:"open.party") { |event| handled << [:"open.party", event.name] }
    end
    subscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("open.party.doodle")

    assert_equal [[:open, "open.party.doodle"]], handled
  ensure
    subscriber.detach_from :doodle
  end

  def test_attaches_and_detaches_subscribers_with_regexp_patterns
    handled = []
    subscriber = Class.new(ActiveSupport::Subscriber) do
      def self.prepare_pattern(event) = /\A#{event}\.doodle\z/
      define_method(:open_party) { |event| handled << event.name }
    end
    subscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("open_party.doodle")
    subscriber.detach_from :doodle
    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal ["open_party.doodle"], handled
  ensure
    subscriber.detach_from :doodle
  end

  def test_event_method_names_stay_shareable_with_string_subclass_patterns
    pattern_class = Class.new(String)
    handled = []
    subscriber = Class.new(ActiveSupport::Subscriber) do
      define_singleton_method(:prepare_pattern) { |event| pattern_class.new("#{event}.doodle") }
      define_method(:open_party) { |event| handled << event.name }
    end
    subscriber.attach_to :doodle

    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal ["open_party.doodle"], handled
    assert Ractor.shareable?(subscriber.event_method_names)
  ensure
    subscriber.detach_from :doodle
  end

  def test_subscriber_that_skips_super_in_initialize_receives_events_when_subscribed_directly
    handled = []
    subscriber = Class.new(ActiveSupport::Subscriber) do
      def initialize; end
      define_method(:hello) { |event| handled << event.name }
    end

    subscription = ActiveSupport::Notifications.subscribe("hello.manual", subscriber.new)
    ActiveSupport::Notifications.instrument("hello.manual")

    assert_equal ["hello.manual"], handled
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end
end
