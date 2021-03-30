# frozen_string_literal: true

module ActionController
  # Encasulates logic needed to contruct payload for controller events.
  module InstrumentationPayload
    private
      # The payload data used by the following instrumented events:
      # * start_processing.action_controller
      # * process_action.action_controller
      def controller_instrumentation_payload
        {
          controller: self.class.name,
          action: action_name,
          request: request,
          params: request.filtered_parameters,
          headers: request.headers,
          format: request.format.ref,
          method: request.request_method,
          path: request.fullpath
        }
      end
  end
end