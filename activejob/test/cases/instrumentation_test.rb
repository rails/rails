# frozen_string_literal: true

require "helper"
require "jobs/rescue_job"
require "jobs/hello_job"
require "models/person"

class InstrumentationTest < ActiveSupport::TestCase
  def subscription_events(key)
    [].tap do |events|
      subscription = ActiveSupport::Notifications.subscribe(/#{key}\.active_job/) { |event|
        events << event
      }

      yield

      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end

  test "do not instrument errors when already handled" do
    events = subscription_events(:unhandled_error) {
      RescueJob.perform_now("david")
    }

    assert_equal 0, events.length
  end

  test "instrument unhandled errors from perform" do
    events = subscription_events(:unhandled_error) {
      assert_raises(RescueJob::OtherError) do
        RescueJob.perform_now("other")
      end
    }

    assert_equal 1, events.length
    assert_instance_of RescueJob::OtherError, events.first.payload[:error]
  end

  test "instrument unhandled errors from enqueue" do
    events = subscription_events(:unhandled_error) {
      assert_raises(ActiveJob::DeserializationError) do
        HelloJob.perform_later Person.new(404)
      end
    }

    assert_equal 1, events.length
    assert_instance_of ActiveJob::DeserializationError, events.first.payload[:error]
  end
end
