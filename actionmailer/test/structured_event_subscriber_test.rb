# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/event_reporter_assertions"
require "mailers/base_mailer"
require "action_mailer/structured_event_subscriber"

module ActionMailer
  class StructuredEventSubscriberTest < ActionMailer::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    class BogusDelivery
      def initialize(*)
      end

      def deliver!(mail)
        raise "failed"
      end
    end

    def run(*)
      with_debug_event_reporting do
        super
      end
    end

    def test_deliver_is_notified
      event = assert_event_reported("action_mailer.delivered", payload: { message_id: "123@abc", mail: /.*/, perform_deliveries: true }) do
        BaseMailer.welcome(message_id: "123@abc").deliver_now
      end

      assert event[:payload][:duration] > 0
    ensure
      BaseMailer.deliveries.clear
    end

    def test_deliver_message_when_perform_deliveries_is_false
      assert_event_reported("action_mailer.delivered", payload: { message_id: "123@abc", mail: /.*/, perform_deliveries: false }) do
        BaseMailer.welcome_without_deliveries(message_id: "123@abc").deliver_now
      end
    ensure
      BaseMailer.deliveries.clear
    end

    def test_deliver_message_when_exception_happened
      previous_delivery_method = BaseMailer.delivery_method
      BaseMailer.delivery_method = BogusDelivery
      payload = { message_id: "123@abc", mail: /.*/, exception_class: "RuntimeError", exception_message: "failed" }

      assert_event_reported("action_mailer.delivered", payload:) do
        assert_raises(RuntimeError) { BaseMailer.welcome(message_id: "123@abc").deliver_now }
      end
    ensure
      BaseMailer.delivery_method = previous_delivery_method
    end
  end
end
