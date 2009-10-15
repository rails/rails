require 'thread'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'

module ActiveSupport
  # Notifications provides an instrumentation API for Ruby. To instrument an
  # action in Ruby you just need to do:
  #
  #   ActiveSupport::Notifications.instrument(:render, :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  # You can consume those events and the information they provide by registering
  # a subscriber. For instance, let's store all instrumented events in an array:
  #
  #   @events = []
  #
  #   ActiveSupport::Notifications.subscribe do |event|
  #     @events << event
  #   end
  #
  #   ActiveSupport::Notifications.instrument(:render, :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  #   event = @events.first
  #   event.class     #=> ActiveSupport::Notifications::Event
  #   event.name      #=> :render
  #   event.duration  #=> 10 (in miliseconds)
  #   event.result    #=> "Foo"
  #   event.payload   #=> { :extra => :information }
  #
  # When subscribing to Notifications, you can pass a pattern, to only consume
  # events that match the pattern:
  #
  #   ActiveSupport::Notifications.subscribe(/render/) do |event|
  #     @render_events << event
  #   end
  #
  # Notifications ships with a queue implementation that consumes and publish events
  # to subscribers in a thread. You can use any queue implementation you want.
  #
  module Notifications
    mattr_accessor :queue

    class << self
      delegate :instrument, :to => :instrumenter

      def instrumenter
        Thread.current[:notifications_instrumeter] ||= Instrumenter.new(publisher)
      end

      def publisher
        @publisher ||= Publisher.new(queue)
      end

      def subscribe(pattern=nil, &block)
        Subscriber.new(queue).bind(pattern).subscribe(&block)
      end
    end

    class Instrumenter
      def initialize(publisher)
        @publisher = publisher
      end

      def instrument(name, payload={})
        payload[:time]      = Time.now
        payload[:thread_id] = Thread.current.object_id
        payload[:result]    = yield if block_given?
      ensure
        payload[:duration] = 1000 * (Time.now.to_f - payload[:time].to_f)
        @publisher.publish(name, payload)
      end
    end

    class Publisher
      def initialize(queue)
        @queue = queue
      end

      def publish(name, payload)
        @queue.publish(name, payload)
      end
    end

    class Subscriber
      def initialize(queue)
        @queue = queue
      end

      def bind(pattern)
        @pattern = pattern
        self
      end

      def subscribe
        @queue.subscribe(@pattern) do |name, payload|
          yield Event.new(name, payload)
        end
      end
    end

    class Event
      attr_reader :name, :time, :duration, :thread_id, :result, :payload

      def initialize(name, payload)
        @name      = name
        @payload   = payload.dup
        @time      = @payload.delete(:time)
        @thread_id = @payload.delete(:thread_id)
        @result    = @payload.delete(:result)
        @duration  = @payload.delete(:duration)
      end

      def parent_of?(event)
        start = (self.time - event.time) * 1000
        start <= 0 && (start + self.duration >= event.duration)
      end
    end

    # This is a default queue implementation that ships with Notifications. It
    # consumes events in a thread and publish them to all registered subscribers.
    #
    class LittleFanout
      def initialize
        @listeners, @stream = [], Queue.new
        @thread = Thread.new { consume }
      end

      def publish(*event)
        @stream.push(event)
      end

      def subscribe(pattern=nil, &block)
        @listeners << Listener.new(pattern, &block)
      end

      def consume
        while event = @stream.shift
          @listeners.each { |l| l.publish(*event) }
        end
      end

      class Listener
        attr_reader :thread

        def initialize(pattern, &block)
          @pattern = pattern
          @subscriber = block
          @queue = Queue.new
          @thread = Thread.new { consume }
        end

        def publish(name, payload)
          unless @pattern && !(@pattern === name.to_s)
            @queue << [name, payload]
          end
        end

        def consume
          while event = @queue.shift
            @subscriber.call(*event)
          end
        end
      end
    end
  end

  Notifications.queue = Notifications::LittleFanout.new
end
