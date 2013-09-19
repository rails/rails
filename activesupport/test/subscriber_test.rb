require 'abstract_unit'
require 'active_support/subscriber'

class TestSubscriber < ActiveSupport::Subscriber
  attach_to :doodle

  cattr_reader :event

  def self.clear
    @@event = nil
  end

  def open_party(event)
    @@event = event
  end

  private

  def private_party(event)
    @@event = event
  end
end

class SubscriberTest < ActiveSupport::TestCase
  def setup
    TestSubscriber.clear
  end

  def test_attaches_subscribers
    ActiveSupport::Notifications.instrument("open_party.doodle")

    assert_equal "open_party.doodle", TestSubscriber.event.name
  end

  def test_does_not_attach_private_methods
    ActiveSupport::Notifications.instrument("private_party.doodle")

    assert_nil TestSubscriber.event
  end
end
