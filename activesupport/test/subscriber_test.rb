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
end
