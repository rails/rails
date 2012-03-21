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
        subscriber = Subscribers.new pattern, block
        @subscribers << subscriber
        @listeners_for.clear
        subscriber
      end

      def unsubscribe(subscriber)
        @subscribers.reject! { |s| s.matches?(subscriber) }
        @listeners_for.clear
      end

      def start(name, id, payload)
        listeners_for(name).each { |s| s.start(name, id, payload) }
      end

      def finish(name, id, payload)
        listeners_for(name).each { |s| s.finish(name, id, payload) }
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

      module Subscribers # :nodoc:
        def self.new(pattern, block)
          if pattern
            TimedSubscriber.new pattern, block
          else
            AllMessages.new pattern, block
          end
        end

        class Subscriber #:nodoc:
          def initialize(pattern, delegate)
            @pattern = pattern
            @delegate = delegate
          end

          def start(name, id, payload)
            raise NotImplementedError
          end

          def finish(name, id, payload)
            raise NotImplementedError
          end

          def subscribed_to?(name)
            @pattern === name.to_s
          end

          def matches?(subscriber_or_name)
            self === subscriber_or_name ||
              @pattern && @pattern === subscriber_or_name
          end
        end

        class TimedSubscriber < Subscriber
          def initialize(pattern, delegate)
            @timestack = Hash.new { |h,id|
              h[id] = Hash.new { |ids,name| ids[name] = [] }
            }
            super
          end

          def publish(name, *args)
            @delegate.call name, *args
          end

          def start(name, id, payload)
            @timestack[id][name].push Time.now
          end

          def finish(name, id, payload)
            started = @timestack[id][name].pop
            @delegate.call(name, started, Time.now, id, payload)
          end
        end

        class AllMessages < TimedSubscriber # :nodoc:
          def subscribed_to?(name)
            true
          end

          alias :matches? :===
        end
      end
    end
  end
end
