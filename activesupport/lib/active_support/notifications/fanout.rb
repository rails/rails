require 'thread'

module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications. It
    # consumes events in a thread and publish them to all registered subscribers.
    #
    class Fanout
      def initialize(sync = false)
        @subscriber_klass = sync ? Subscriber : AsyncSubscriber
        @subscribers = []
      end

      def bind(pattern)
        Binding.new(self, pattern)
      end

      def subscribe(pattern = nil, &block)
        @subscribers << @subscriber_klass.new(pattern, &block)
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

      class Subscriber #:nodoc:
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

      # Used for internal implementation only.
      class AsyncSubscriber < Subscriber #:nodoc:
        def initialize(pattern, &block)
          super
          @events = Queue.new
          start_consumer
        end

        def drained?
          @events.empty?
        end

        private
          def start_consumer
            Thread.new { consume }
          end

          def consume
            while args = @events.shift
              @block.call(*args)
            end
          end

          def push(*args)
            @events << args
          end
      end
    end
  end
end
