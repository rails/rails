require "abstract_unit"
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
end
