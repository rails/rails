# frozen_string_literal: true

require "active_support/structured_event_subscriber"

module ActionMailer
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    # An email was delivered.
    def deliver(event)
      if (exception = event.payload[:exception_object])
        emit_debug_event("action_mailer.delivery_error",
          message_id: event.payload[:message_id],
          exception_class: exception.class.name,
          exception_message:  exception.message,
          mail: event.payload[:mail],
        )
      elsif event.payload[:perform_deliveries]
        emit_debug_event("action_mailer.delivered",
          message_id: event.payload[:message_id],
          duration: event.duration.round(1),
          mail: event.payload[:mail],
        )
      else
        emit_debug_event("action_mailer.delivery_skipped",
          message_id: event.payload[:message_id],
          mail: event.payload[:mail],
        )
      end
    end

    # An email was generated.
    def process(event)
      emit_debug_event("action_mailer.processed",
        mailer: event.payload[:mailer],
        action: event.payload[:action],
        duration: event.duration.round(1),
      )
    end
  end
end

ActionMailer::StructuredEventSubscriber.attach_to :action_mailer
