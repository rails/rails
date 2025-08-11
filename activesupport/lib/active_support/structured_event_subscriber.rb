# frozen_string_literal: true

require "active_support/subscriber"

module ActiveSupport
  # = Active Support Structured Event \Subscriber
  #
  # +ActiveSupport::StructuredEventSubscriber+ consumes ActiveSupport::Notifications
  # in order to emit structured events via +Rails.event+.
  #
  # An example would be the Action Controller structured event subscriber, responsible for
  # emitting request processing events:
  #
  #   module ActionController
  #     class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber
  #       attach_to :action_controller
  #
  #       def start_processing(event)
  #         emit_event("controller.request_started",
  #           controller: event.payload[:controller],
  #           action: event.payload[:action],
  #           format: event.payload[:format]
  #         )
  #       end
  #     end
  #   end
  #
  # After configured, whenever a <tt>"start_processing.action_controller"</tt> notification is published,
  # it will properly dispatch the event (+ActiveSupport::Notifications::Event+) to the +start_processing+ method.
  # The subscriber can then emit a structured event via the +emit_event+ method.
  class StructuredEventSubscriber < Subscriber
    # Emit a structured event via Rails.event.notify.
    #
    # ==== Arguments
    #
    # * +name+ - The event name as a string or symbol
    # * +payload+ - The event payload as a hash or object
    # * +caller_depth+ - Stack depth for source location (default: 1)
    # * +kwargs+ - Additional payload data merged with the payload hash
    def emit_event(name, payload = nil, caller_depth: 1, **kwargs)
      ActiveSupport.event_reporter.notify(name, payload, caller_depth: caller_depth + 1, **kwargs)
    rescue => e
      handle_event_error(name, e)
    end

    # Like +emit_event+, but only emits when the event reporter is in debug mode
    def emit_debug_event(name, payload = nil, caller_depth: 1, **kwargs)
      ActiveSupport.event_reporter.debug(name, payload, caller_depth: caller_depth + 1, **kwargs)
    rescue => e
      handle_event_error(name, e)
    end

    def call(event)
      super
    rescue => e
      handle_event_error(event.name, e)
    end

    def publish_event(event)
      super
    rescue => e
      handle_event_error(event.name, e)
    end

    private
      def handle_event_error(name, error)
        ActiveSupport.error_reporter.report(error, source: name)
      end
  end
end
