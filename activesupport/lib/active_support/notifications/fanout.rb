module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications. It
    # just pushes events to all registered log subscribers.
    class Fanout
      def initialize
        @subscribers = []
        @listeners_for = {}
      end

      def bind(pattern)
        Binding.new(self, pattern)
      end

      def subscribe(pattern = nil, &block)
        @listeners_for.clear
        @subscribers << Subscriber.new(pattern, &block)
        @subscribers.last
      end

      def unsubscribe(subscriber)
        @subscribers.delete(subscriber)
        @listeners_for.clear
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

      # Used for internal implementation only.
      class Binding #:nodoc:
        def initialize(queue, pattern)
          @queue = queue
          @pattern =
            case pattern
            when Regexp, NilClass
              pattern
            else
              /^#{Regexp.escape(pattern.to_s)}$/
            end
        end

        def subscribe(&block)
          @queue.subscribe(@pattern, &block)
        end
      end

      class Subscriber #:nodoc:
        def initialize(pattern, &block)
          @pattern = pattern
          @block = block
        end

        def publish(*args)
          return unless matches?(args.first)
          push(*args)
          true
        end

        def drained?
          true
        end

        private
          def matches?(name)
            !@pattern || @pattern =~ name.to_s
          end

          def push(*args)
            @block.call(*args)
          end
      end
    end
  end
end
