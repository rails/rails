# :markup: markdown
# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/subscriber"

module ActiveSupport
  # Active Support Structured Event \Subscriber
  # ===========================================
  #
  # `ActiveSupport::StructuredEventSubscriber` consumes ActiveSupport::Notifications
  # in order to emit structured events via `Rails.event`.
  #
  # An example would be the Action Controller structured event subscriber, responsible for
  # emitting request processing events:
  #
  # ```
  # module ActionController
  #   class StructuredEventSubscriber < ActiveSupport::StructuredEventSubscriber
  #     attach_to :action_controller
  #
  #     def start_processing(event)
  #       emit_event("controller.request_started",
  #         controller: event.payload[:controller],
  #         action: event.payload[:action],
  #         format: event.payload[:format]
  #       )
  #     end
  #   end
  # end
  # ```
  #
  # After configured, whenever a `"start_processing.action_controller"` notification is published,
  # it will properly dispatch the event (`ActiveSupport::Notifications::Event`) to the `start_processing` method.
  # The subscriber can then emit a structured event via the `emit_event` method.
  class StructuredEventSubscriber < Subscriber
    class_attribute :debug_methods, instance_accessor: false, default: [] # :nodoc:
    class_attribute :emitted_events, instance_accessor: false, default: {}.freeze # :nodoc:

    # Checking whether an event is consumed costs about as much as notifying
    # it, and Notifications checks twice per event, so once an event is found
    # to be consumed, this many checks are skipped.
    CHECKS_SKIPPED_WHILE_CONSUMED = 63 # :nodoc:

    class << self
      def attach_to(...) # :nodoc:
        result = super
        set_silenced_events
        result
      end

      private
        def set_silenced_events
          if subscriber
            subscriber.silenced_events = debug_methods.to_h { |method| ["#{method}.#{namespace}", true] }
            subscriber.emitted_events = emitted_events.to_h { |method, name| ["#{method}.#{namespace}", name] }
          end
        end

        def debug_only(method)
          self.debug_methods += [method]
          set_silenced_events
        end

        # Declares that +method+ emits no event other than +name+, so that its
        # notifications are silenced while no event reporter subscriber would
        # consume +name+, instead of building a payload that would go nowhere.
        def emits(method, name)
          self.emitted_events = emitted_events.merge(method => name).freeze
          set_silenced_events
        end
    end

    def initialize
      super
      @silenced_events = {}
      @emitted_events = {}
      @checks_to_skip = 0
    end

    def silenced?(event)
      event_reporter = ActiveSupport.event_reporter

      event_reporter.subscribers.none? ||
        (@silenced_events.key?(event) && !event_reporter.debug_mode?) ||
        unconsumed?(event, event_reporter)
    end

    attr_writer :silenced_events, :emitted_events # :nodoc:

    # Whether any event reporter subscriber would currently consume an event
    # with the given name. Handlers can use this to skip building payloads
    # for events that would go nowhere.
    def emitting?(name)
      ActiveSupport.event_reporter.emitting?(name)
    end

    # Emit a structured event via Rails.event.notify.
    #
    # #### Arguments
    #
    # * `name` - The event name as a string or symbol
    # * `payload` - The event payload as a hash or object
    # * `caller_depth` - Stack depth for source location (default: 1)
    # * `kwargs` - Additional payload data merged with the payload hash
    def emit_event(name, payload = nil, caller_depth: 1, **kwargs)
      ActiveSupport.event_reporter.notify(name, payload, caller_depth: caller_depth + 1, filter_payload: false, **kwargs)
    rescue => e
      handle_event_error(name, e)
    end

    # Like `emit_event`, but only emits when the event reporter is in debug mode
    def emit_debug_event(name, payload = nil, caller_depth: 1, **kwargs)
      ActiveSupport.event_reporter.debug(name, payload, caller_depth: caller_depth + 1, filter_payload: false, **kwargs)
    rescue => e
      handle_event_error(name, e)
    end

    def call(event)
      super
    rescue => e
      handle_event_error(event.name, e)
    end

    private
      def handle_event_error(name, error)
        ActiveSupport.error_reporter.report(error, source: name)
      end

      # The handler for +event+ emits only the event it was declared with, and
      # notifying it does nothing unless some subscriber consumes it. Not
      # silencing is always safe: the handler then runs as if undeclared.
      #
      # This runs when the notification is instrumented, outside of #call, so
      # errors (e.g. from a subscription filter) are left to the handler, which
      # reports them.
      def unconsumed?(event, event_reporter)
        name = @emitted_events[event]
        # Subscribers copied into a non-main Ractor are frozen, so they can't
        # count skipped checks and always notify.
        return false unless name && !frozen?

        if @checks_to_skip > 0
          @checks_to_skip -= 1
          return false
        end

        consumed = event_reporter.emitting?(name)
        @checks_to_skip = CHECKS_SKIPPED_WHILE_CONSUMED if consumed
        !consumed
      rescue StandardError
        false
      end
  end
end
