module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications. It
    # just pushes events to all registered log subscribers.
    class Fanout
      def initialize
        @subscribers = []
        @listeners_for = {}
        @pattern = nil
      end

      def bind(pattern)
        @pattern = pattern
        self
      end

      def subscribe(pattern = @pattern, &block)
        @listeners_for.clear
        @subscribers << Subscriber.new(pattern, &block)
        @subscribers.last
      end

      def unsubscribe(subscriber)
        @listeners_for.clear
        @subscribers.reject! {|s| s.matches?(subscriber)}
      end

      def publish(name, *args)
        if listeners = @listeners_for[name]
          listeners.each { |s| s.publish(name, *args) }
        else
          @listeners_for[name] = @subscribers.select { |s| s.publish(name, *args) }
        end
      end

      # This is a sync queue, so there is not waiting.
      def wait
      end

      class Subscriber #:nodoc:
        def initialize(pattern, &block)
          @pattern = pattern
          @block = block
        end

        def publish(*args)
          return unless subscribed_to?(args.first)
          @block.call(*args)
          true
        end

        def drained?
          true
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
