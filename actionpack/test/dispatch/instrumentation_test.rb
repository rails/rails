# frozen_string_literal: true

require "abstract_unit"

class InstrumentationTest < ActionDispatch::IntegrationTest
  Subscriber = Struct.new(:starts, :finishes) do
    def initialize(starts = [], finishes = [])
      super
    end

    def start(name, id, payload)
      starts << [name, id, payload]
    end

    def finish(name, id, payload)
      finishes << [name, id, payload]
    end
  end

  attr_reader :subscriber, :notifier

  def setup
    @subscriber = Subscriber.new
    @notifier = ActiveSupport::Notifications.notifier
    @subscription = notifier.subscribe "request.action_dispatch", subscriber
  end

  def teardown
    notifier.unsubscribe @subscription
  end

  def test_notification
    @app = ActionDispatch::Instrumentation.new(->(env) { [200, {}, %w(Success)] })

    assert_difference("subscriber.starts.length") do
      assert_difference("subscriber.finishes.length") do
        get "/"
      end
    end
  end

  def test_notification_on_raise
    @app = ActionDispatch::Instrumentation.new(->(env) {
      # using an exception class that is not a StandardError subclass on purpose
      raise NotImplementedError
    })

    assert_difference("subscriber.starts.length") do
      assert_difference("subscriber.finishes.length") do
        assert_raises(NotImplementedError) do
          get "/"
        end
      end
    end
  end
end
