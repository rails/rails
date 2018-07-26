# frozen_string_literal: true

require "mutex_m"
require "concurrent/map"

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
        @listeners_for = Concurrent::Map.new
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

      def unsubscribe(subscriber_or_name)
        synchronize do
          case subscriber_or_name
          when String
            @subscribers.reject! { |s| s.matches?(subscriber_or_name) }
          else
            @subscribers.delete(subscriber_or_name)
          end

          @listeners_for.clear
        end
      end

      def start(name, id, payload)
        listeners_for(name).each { |s| s.start(name, id, payload) }
      end

      def finish(name, id, payload, listeners = listeners_for(name))
        listeners.each { |s| s.finish(name, id, payload) }
      end

      def publish(name, *args)
        listeners_for(name).each { |s| s.publish(name, *args) }
      end

      def listeners_for(name)
        # this is correctly done double-checked locking (Concurrent::Map's lookups have volatile semantics)
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
          if listener.respond_to?(:start) && listener.respond_to?(:finish)
            subscriber_class = Evented
          else
            if listener.respond_to?(:arity) && listener.arity == 1
              subscriber_class = EventObject
            else
              subscriber_class = Timed
            end
          end

          wrap_all pattern, subscriber_class.new(pattern, listener)
        end

        def self.event_object_subscriber(pattern, block)
          wrap_all pattern, EventObject.new(pattern, block)
        end

        def self.wrap_all(pattern, subscriber)
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
            @can_publish = delegate.respond_to?(:publish)
          end

          def publish(name, *args)
            if @can_publish
              @delegate.publish name, *args
            end
          end

          def start(name, id, payload)
            @delegate.start name, id, payload
          end

          def finish(name, id, payload)
            @delegate.finish name, id, payload
          end

          def subscribed_to?(name)
            @pattern === name
          end

          def matches?(name)
            @pattern && @pattern === name
          end
        end

        class Timed < Evented # :nodoc:
          def publish(name, *args)
            @delegate.call name, *args
          end

          def start(name, id, payload)
            timestack = Thread.current[:_timestack] ||= []
            timestack.push Time.now
          end

          def finish(name, id, payload)
            timestack = Thread.current[:_timestack]
            started = timestack.pop
            @delegate.call(name, started, Time.now, id, payload)
          end
        end

        class EventObject < Evented
          def start(name, id, payload)
            stack = Thread.current[:_event_stack] ||= []
            event = build_event name, id, payload
            event.start!
            stack.push event
          end

          def finish(name, id, payload)
            stack = Thread.current[:_event_stack]
            event = stack.pop
            event.finish!
            @delegate.call event
          end

          private
            def build_event(name, id, payload)
              ActiveSupport::Notifications::Event.new name, nil, nil, id, payload
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
