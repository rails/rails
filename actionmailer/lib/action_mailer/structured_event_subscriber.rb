# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActionMailer
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    # An email was delivered.
    def deliver(event)
      exception = event.payload[:exception_object]
      payload = {
        message_id: event.payload[:message_id],
        duration: event.duration.round(2),
        mail: event.payload[:mail],
        perform_deliveries: event.payload[:perform_deliveries],
      }

      if exception
        payload[:exception_class] = exception.class.name
        payload[:exception_message] = exception.message
      end

      emit_debug_event("action_mailer.delivered", payload)
    end
    debug_only :deliver

    # An email was generated.
    def process(event)
      emit_debug_event("action_mailer.processed",
        mailer: event.payload[:mailer],
        action: event.payload[:action],
        duration: event.duration.round(2),
      )
    end
    debug_only :process
  end
end

ActionMailer::StructuredEventSubscriber.attach_to :action_mailer
