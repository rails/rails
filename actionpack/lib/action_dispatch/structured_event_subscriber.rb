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

    class Start # :nodoc:
      def silenced?(_name)
        ActiveSupport.event_reporter.subscribers.none?
      end

      def start(name, id, payload)
        request = payload[:request]

        ActiveSupport.event_reporter.notify("action_dispatch.request_started",
          filter_payload: false,
          method: request.raw_request_method,
          path: request.filtered_path,
          remote_ip: request.remote_ip,
        )
      end

      def finish(name, id, payload)
      end
    end

    def self.attach_to(*)
      ActiveSupport::Notifications.subscribe("request.action_dispatch", Start.new)

      super
    end
  end
end

ActionDispatch::StructuredEventSubscriber.attach_to :action_dispatch
