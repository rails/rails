module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications. It
    # just pushes events to all registered log subscribers.
    class Fanout
      def initialize
        @log_subscribers = []
      end

      def bind(pattern)
        Binding.new(self, pattern)
      end

      def subscribe(pattern = nil, &block)
        @log_subscribers << LogSubscriber.new(pattern, &block)
      end

      def publish(*args)
        @log_subscribers.each { |s| s.publish(*args) }
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
              /^#{Regexp.escape(pattern.to_s)}/
            end
        end

        def subscribe(&block)
          @queue.subscribe(@pattern, &block)
        end
      end

      class LogSubscriber #:nodoc:
        def initialize(pattern, &block)
          @pattern = pattern
          @block = block
        end

        def publish(*args)
          push(*args) if matches?(args.first)
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
