require 'mutex_m'
require 'thread_safe'

module ActiveSupport
  module Notifications
    # This is a default queue implementation that ships with Notifications.
    # It just pushes events to all registered log subscribers.
    #
    # This class is thread safe. All methods are reentrant.
    class Fanout
      include Mutex_m

      def initialize
        @subscribers = []
        @listeners_for = ThreadSafe::Cache.new
        super
      end

      def subscribe(pattern = nil, block = Proc.new)
        subscriber = Subscribers.new pattern, block
        synchronize do
          @subscribers << subscriber
          @listeners_for.clear
        end
        subscriber
      end

      def unsubscribe(subscriber)
        synchronize do
          @subscribers.reject! { |s| s.matches?(subscriber) }
          @listeners_for.clear
        end
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
        # this is correctly done double-checked locking (ThreadSafe::Cache's lookups have volatile semantics)
        @listeners_for[name] || synchronize do
          # use synchronisation when accessing @subscribers
          @listeners_for[name] ||= @subscribers.select { |s| s.subscribed_to?(name) }
        end
      end

      def listening?(name)
        listeners_for(name).any?
      end

      # This is a sync queue, so there is no waiting.
      def wait
      end

      module Subscribers # :nodoc:
        def self.new(pattern, listener)
          if listener.respond_to?(:start) and listener.respond_to?(:finish)
            subscriber = Evented.new pattern, listener
          else
            subscriber = Timed.new pattern, listener
          end

          unless pattern
            AllMessages.new(subscriber)
          else
            subscriber
          end
        end

        class Evented #:nodoc:
          def initialize(pattern, delegate)
            @pattern = pattern
            @delegate = delegate
          end

          def start(name, id, payload)
            @delegate.start name, id, payload
          end

          def finish(name, id, payload)
            @delegate.finish name, id, payload
          end

          def subscribed_to?(name)
            @pattern === name.to_s
          end

          def matches?(subscriber_or_name)
            self === subscriber_or_name ||
              @pattern && @pattern === subscriber_or_name
          end
        end

        class Timed < Evented
          def initialize(pattern, delegate)
            @timestack = []
            super
          end

          def publish(name, *args)
            @delegate.call name, *args
          end

          def start(name, id, payload)
            @timestack.push Time.now
          end

          def finish(name, id, payload)
            started = @timestack.pop
            @delegate.call(name, started, Time.now, id, payload)
          end
        end

        class AllMessages # :nodoc:
          def initialize(delegate)
            @delegate = delegate
          end

          def start(name, id, payload)
            @delegate.start name, id, payload
          end

          def finish(name, id, payload)
            @delegate.finish name, id, payload
          end

          def publish(name, *args)
            @delegate.publish name, *args
          end

          def subscribed_to?(name)
            true
          end

          alias :matches? :===
        end
      end
    end
  end
end
