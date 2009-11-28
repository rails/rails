require 'thread'

module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications. It
    # consumes events in a thread and publish them to all registered subscribers.
    #
    class Fanout
      def initialize
        @subscribers = []
      end

      def bind(pattern)
        Binding.new(self, pattern)
      end

      def subscribe(pattern = nil, &block)
        @subscribers << Subscriber.new(pattern, &block)
      end

      def publish(*args)
        @subscribers.each { |s| s.publish(*args) }
      end

      def wait
        sleep(0.05) until @subscribers.all?(&:drained?)
      end

      # Used for internal implementation only.
      class Binding #:nodoc:
        def initialize(queue, pattern)
          @queue, @pattern = queue, pattern
        end

        def subscribe(&block)
          @queue.subscribe(@pattern, &block)
        end
      end

      # Used for internal implementation only.
      class Subscriber #:nodoc:
        def initialize(pattern, &block)
          @pattern =
            case pattern
            when Regexp, NilClass
              pattern
            else
              /^#{Regexp.escape(pattern.to_s)}/
            end
          @block = block
          @events = Queue.new
          start_consumer
        end

        def publish(name, *args)
          push(name, args) if matches?(name)
        end

        def consume
          while args = @events.shift
            @block.call(*args)
          end
        end

        def drained?
          @events.size.zero?
        end

        private
          def start_consumer
            Thread.new { consume }
          end

          def matches?(name)
            !@pattern || @pattern =~ name.to_s
          end

          def push(name, args)
            @events << args.unshift(name)
          end
      end
    end
  end
end
