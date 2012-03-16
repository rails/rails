module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications.
    # It just pushes events to all registered log subscribers.
    class Fanout
      def initialize
        @subscribers = []
        @listeners_for = {}
      end

      def subscribe(pattern = nil, block = Proc.new)
        subscriber = Subscriber.new(pattern, block)
        @subscribers << subscriber
        @listeners_for.clear
        subscriber
      end

      def unsubscribe(subscriber)
        @subscribers.reject! { |s| s.matches?(subscriber) }
        @listeners_for.clear
      end

      def publish(name, *args)
        listeners_for(name).each { |s| s.publish(name, *args) }
      end

      def listeners_for(name)
        @listeners_for[name] ||= @subscribers.select { |s| s.subscribed_to?(name) }
      end

      def listening?(name)
        listeners_for(name).any?
      end

      # This is a sync queue, so there is no waiting.
      def wait
      end

      class Subscriber #:nodoc:
        def initialize(pattern, delegate)
          @pattern = pattern
          @delegate = delegate
        end

        def publish(message, *args)
          @delegate.call(message, *args)
        end

        def subscribed_to?(name)
          !@pattern || @pattern === name.to_s
        end

        def matches?(subscriber_or_name)
          self === subscriber_or_name ||
            @pattern && @pattern === subscriber_or_name
        end
      end
    end
  end
end
