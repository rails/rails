# :markup: markdown
# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/subscriber"
require "concurrent/map"

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

    CHECKS_SKIPPED_WHILE_NOT_IGNORED = 63 # :nodoc:

    class << self
      # The namespace shared by every event this subscriber emits, i.e. each
      # emitted name starts with <tt>"#{event_namespace}."</tt>. When set,
      # notifications are silenced while no +Rails.event+ subscriber would act on
      # the resulting events, such as log subscribers whose logger level is above
      # all of their events in that namespace.
      #
      # Not inherited, as subclasses may emit events in other namespaces.
      attr_accessor :event_namespace # :nodoc:

      def attach_to(...) # :nodoc:
        result = super
        set_silenced_events
        result
      end

      private
        def set_silenced_events
          if subscriber
            subscriber.silenced_events = debug_methods.to_h { |method| ["#{method}.#{namespace}", true] }
          end
        end

        def debug_only(method)
          self.debug_methods += [method]
          set_silenced_events
        end
    end

    def initialize
      super
      @silenced_events = {}
      @log_level_predicates = Concurrent::Map.new
      @checks_to_skip = 0
    end

    def silenced?(event)
      event_reporter = ActiveSupport.event_reporter
      subscribers = event_reporter.subscribers

      subscribers.none? ||
        (@silenced_events.key?(event) && !event_reporter.debug_mode?) ||
        ignored_by_all?(subscribers)
    end

    attr_writer :silenced_events # :nodoc:

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

      def ignored_by_all?(subscribers)
        namespace = self.class.event_namespace
        return false unless namespace

        # A check costs about as much as the log level checks done when the
        # event is emitted, so once some subscriber is found to act on events,
        # skip the next checks. Events that aren't silenced are still filtered
        # when emitted, so this never changes what is logged.
        if @checks_to_skip > 0
          @checks_to_skip -= 1
          return false
        end

        ignored = subscribers.all? { |entry| ignored_by?(entry, namespace, subscribers.size) }
        @checks_to_skip = CHECKS_SKIPPED_WHILE_NOT_IGNORED unless ignored
        ignored
      end

      # Whether the event reporter subscriber +entry+ is guaranteed to do nothing
      # with any event emitted in +namespace+ under the current log level.
      def ignored_by?(entry, namespace, subscribers_count)
        subscriber = entry[:subscriber]
        return false unless EventReporter::LogSubscriber === subscriber

        predicates = log_level_predicates(subscriber, entry[:filter], namespace, subscribers_count)
        return false unless predicates
        # Don't touch the logger when no event in the namespace is logged at all.
        return true if predicates.empty?

        logger = subscriber.logger
        !logger || predicates.none? { |predicate| logger.public_send(predicate) }
      rescue StandardError, NotImplementedError
        false
      end

      def log_level_predicates(subscriber, filter, namespace, subscribers_count)
        log_levels = subscriber.log_levels
        cached = @log_level_predicates[subscriber]
        return cached[2] if cached && cached[0].equal?(filter) && cached[1].equal?(log_levels)

        @log_level_predicates.clear if @log_level_predicates.size > subscribers_count * 2
        predicates = subscriber.log_level_predicates_for(namespace, filter)
        @log_level_predicates[subscriber] = [filter, log_levels, predicates]
        predicates
      end
  end
end
