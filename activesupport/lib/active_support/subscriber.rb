require "active_support/per_thread_registry"

module ActiveSupport
  # ActiveSupport::Subscriber is an object set to consume
  # ActiveSupport::Notifications. The subscriber dispatches notifications to
  # a registered object based on its given namespace.
  #
  # An example would be an Active Record subscriber responsible for collecting
  # statistics about queries:
  #
  #   module ActiveRecord
  #     class StatsSubscriber < ActiveSupport::Subscriber
  #       attach_to :active_record
  #
  #       def sql(event)
  #         Statsd.timing("sql.#{event.payload[:name]}", event.duration)
  #       end
  #     end
  #   end
  #
  # After configured, whenever a "sql.active_record" notification is published,
  # it will properly dispatch the event (ActiveSupport::Notifications::Event) to
  # the +sql+ method.
  class Subscriber
    class << self
      # Attach the subscriber to a namespace.
      def attach_to(namespace, subscriber = new, notifier = ActiveSupport::Notifications)
        @namespace  = namespace
        @subscriber = subscriber
        @notifier   = notifier

        subscribers << subscriber

        # Add event subscribers for all existing methods on the class.
        subscriber.public_methods(false).each do |event|
          add_event_subscriber(event)
        end
      end

      # Adds event subscribers for all new methods added to the class.
      def method_added(event)
        # Only public methods are added as subscribers, and only if a notifier
        # has been set up. This means that subscribers will only be set up for
        # classes that call #attach_to.
        if public_method_defined?(event) && notifier
          add_event_subscriber(event)
        end
      end

      def subscribers
        @@subscribers ||= []
      end

      protected

      attr_reader :subscriber, :notifier, :namespace

      def add_event_subscriber(event)
        return if %w{ start finish }.include?(event.to_s)

        pattern = "#{event}.#{namespace}"

        # Don't add multiple subscribers (eg. if methods are redefined).
        return if subscriber.patterns.include?(pattern)

        subscriber.patterns << pattern
        notifier.subscribe(pattern, subscriber)
      end
    end

    attr_reader :patterns # :nodoc:

    def initialize
      @queue_key = [self.class.name, object_id].join "-"
      @patterns  = []
      super
    end

    def start(name, id, payload)
      e = ActiveSupport::Notifications::Event.new(name, Time.now, nil, id, payload)
      parent = event_stack.last
      parent << e if parent

      event_stack.push e
    end

    def finish(name, id, payload)
      finished  = Time.now
      event     = event_stack.pop
      event.end = finished
      event.payload.merge!(payload)

      method = name.split(".".freeze).first
      send(method, event)
    end

    private

      def event_stack
        SubscriberQueueRegistry.instance.get_queue(@queue_key)
      end
  end

  # This is a registry for all the event stacks kept for subscribers.
  #
  # See the documentation of <tt>ActiveSupport::PerThreadRegistry</tt>
  # for further details.
  class SubscriberQueueRegistry # :nodoc:
    extend PerThreadRegistry

    def initialize
      @registry = {}
    end

    def get_queue(queue_key)
      @registry[queue_key] ||= []
    end
  end
end
