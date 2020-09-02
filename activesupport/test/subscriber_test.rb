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

# Monkey patch subscriber to test that only one subscriber per method is added.
class TestSubscriber
  remove_method :open_party
  def open_party(event)
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

  def test_detaches_subscribers_from_specific_events
    TestSubscriber.attach_to :doodle
    TestSubscriber.detach_from :doodle, events: [:open_party]

    ActiveSupport::Notifications.instrument("open_party.doodle")
    ActiveSupport::Notifications.instrument("another_open_party.doodle")

    assert_equal 1, TestSubscriber.events.size
    assert_equal "another_open_party.doodle", TestSubscriber.events.first.name
  ensure
    TestSubscriber.detach_from :doodle
  end

  def test_detach_from_does_not_remove_subscriber_if_only_detaching_from_some_events
    TestSubscriber.attach_to :doodle
    TestSubscriber.detach_from :doodle, events: [:open_party]

    assert_includes ActiveSupport::Subscriber.subscribers.map(&:class), TestSubscriber
  ensure
    TestSubscriber.detach_from :doodle
  end

  def test_detach_from_with_events_can_be_called_multiple_times_in_a_row
    TestSubscriber.attach_to :doodle
    TestSubscriber.detach_from :doodle, events: [:events]
    TestSubscriber.detach_from :doodle, events: [:open_party, :another_open_party]

    ActiveSupport::Notifications.instrument("open_party.doodle")
    ActiveSupport::Notifications.instrument("another_open_party.doodle")

    assert_equal [], TestSubscriber.events

    assert_not_includes ActiveSupport::Subscriber.subscribers.map(&:class), TestSubscriber
  end
end
