# frozen_string_literal: true

module ActionDispatch
  class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber # :nodoc:
    def redirect(event)
      payload = event.payload
      status = payload[:status]

      emit_event("action_dispatch.redirect", {
        location: payload[:location],
        status: status,
        status_name: Rack::Utils::HTTP_STATUS_CODES[status],
        duration_ms: event.duration.round(2),
        source_location: payload[:source_location]
      })
    end
  end
end

ActionDispatch::StructuredEventSubscriber.attach_to :action_dispatch
