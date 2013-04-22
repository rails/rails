require 'active_support/per_thread_registry'

module ActiveSupport
  # ActiveSupport::Subscriber is an object set to consume
  # ActiveSupport::Notifications. The subscriber dispatches notifications to
  # a registered object based on its given namespace.
  #
  # An example would be Active Record subscriber responsible for collecting
  # statistics about queries:
  #
  #   module ActiveRecord
  #     class StatsSubscriber < ActiveSupport::Subscriber
  #       def sql(event)
  #         Statsd.timing("sql.#{event.payload[:name]}", event.duration)
  #       end
  #     end
  #   end
  #
  # And it's finally registered as:
  #
  #   ActiveRecord::StatsSubscriber.attach_to :active_record
  #
  # Since we need to know all instance methods before attaching the log
  # subscriber, the line above should be called after your subscriber definition.
  #
  # After configured, whenever a "sql.active_record" notification is published,
  # it will properly dispatch the event (ActiveSupport::Notifications::Event) to
  # the +sql+ method.
  class Subscriber
    class << self

      # Attach the subscriber to a namespace.
      def attach_to(namespace, subscriber=new, notifier=ActiveSupport::Notifications)
        subscribers << subscriber

        subscriber.public_methods(false).each do |event|
          next if %w{ start finish }.include?(event.to_s)

          notifier.subscribe("#{event}.#{namespace}", subscriber)
        end
      end

      def subscribers
        @@subscribers ||= []
      end
    end

    def initialize
      @queue_key = [self.class.name, object_id].join "-"
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

      method = name.split('.').first
      send(method, event)
    end

    private

      def event_stack
        SubscriberQueueRegistry.get_queue(@queue_key)
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
