# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/subscriber"

class TestSubscriber < ActiveSupport::Subscriber
  attach_to :doodle

  cattr_reader :events

  def self.clear
    @@events = []
  end

  def open_party(event)
    events << event
  end

  private
    def private_party(event)
      events << event
    end
end

class TestSubscriber2 < ActiveSupport::Subscriber
  attach_to :doodle

  cattr_reader :events

  def self.clear
    @@events = []
  end

  def open_party(event)
    events << event
  end

  detach_from :doodle
end

class TestSubscriber3 < ActiveSupport::Subscriber
  attach_to :doodle

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

  detach_from :doodle, events: [:open_party]
end

class TestSubscriber4 < ActiveSupport::Subscriber
  attach_to :doodle

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

  detach_from :doodle, events: [:events]
  detach_from :doodle, events: [:open_party, :another_open_party]
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
    TestSubscriber2.clear
    TestSubscriber3.clear
    TestSubscriber4.clear
  end

  def test_attaches_subscribers
    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal "open_party.doodle", TestSubscriber.events.first.name
  end

  def test_attaches_only_one_subscriber
    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal 1, TestSubscriber.events.size
  end

  def test_does_not_attach_private_methods
    ActiveSupport::Notifications.instrument("private_party.doodle")

    assert_equal [], TestSubscriber.events
  end

  def test_detaches_subscribers
    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal [], TestSubscriber2.events
    assert_equal 1, TestSubscriber.events.size
  end

  def test_detaches_subscribers_from_specific_events
    ActiveSupport::Notifications.instrument("open_party.doodle")
    ActiveSupport::Notifications.instrument("another_open_party.doodle")

    assert_equal 1, TestSubscriber3.events.size
    assert_equal "another_open_party.doodle", TestSubscriber3.events.first.name
  end

  def test_detach_from_does_not_remove_subscriber_if_only_detaching_from_some_events
    assert TestSubscriber3.subscribers.find { |subscriber| subscriber.is_a?(TestSubscriber3) }
  end

  def test_detach_from_with_events_can_be_called_multiple_times_in_a_row
    ActiveSupport::Notifications.instrument("open_party.doodle")
    ActiveSupport::Notifications.instrument("another_open_party.doodle")

    assert_equal [], TestSubscriber4.events

    assert_nil TestSubscriber4.subscribers.find { |subscriber| subscriber.is_a?(TestSubscriber4) }
  end
end
