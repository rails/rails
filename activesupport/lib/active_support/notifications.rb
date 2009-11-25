require 'thread'
require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/secure_random'

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
  #   ActiveSupport::Notifications.subscribe do |*args|
  #     @events << ActiveSupport::Notifications::Event.new(*args)
  #   end
  #
  #   ActiveSupport::Notifications.instrument(:render, :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  #   event = @events.first
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
      delegate :instrument, :transaction_id, :transaction, :to => :instrumenter

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
        @id        = random_id
      end

      def transaction
        @id, old_id = random_id, @id
        yield
      ensure
        @id = old_id
      end

      def transaction_id
        @id
      end

      def instrument(name, payload={})
        time   = Time.now
        result = yield if block_given?
      ensure
        @publisher.publish(name, time, Time.now, result, @id, payload)
      end

    private
      def random_id
        SecureRandom.hex(10)
      end
    end

    class Publisher
      def initialize(queue)
        @queue = queue
      end

      def publish(*args)
        @queue.publish(*args)
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
        @queue.subscribe(@pattern) do |*args|
          yield(*args)
        end
      end
    end

    class Event
      attr_reader :name, :time, :end, :transaction_id, :result, :payload

      def initialize(name, start, ending, result, transaction_id, payload)
        @name           = name
        @payload        = payload.dup
        @time           = start
        @transaction_id = transaction_id
        @end            = ending
        @result         = result
      end

      def duration
        @duration ||= 1000.0 * (@end - @time)
      end

      def parent_of?(event)
        start = (self.time - event.time) * 1000
        start <= 0 && (start + duration >= event.duration)
      end
    end

    # This is a default queue implementation that ships with Notifications. It
    # consumes events in a thread and publish them to all registered subscribers.
    #
    class LittleFanout
      def initialize
        @listeners = []
      end

      def publish(*args)
        @listeners.each { |l| l.publish(*args) }
      end

      def subscribe(pattern=nil, &block)
        @listeners << Listener.new(pattern, &block)
      end

      def drained?
        @listeners.all? &:drained?
      end

      class Listener
        def initialize(pattern, &block)
          @pattern = pattern
          @subscriber = block
          @queue = Queue.new
          Thread.new { consume }
        end

        def publish(name, *args)
          if !@pattern || @pattern === name.to_s
            @queue << args.unshift(name)
          end
        end

        def consume
          while args = @queue.shift
            @subscriber.call(*args)
          end
        end

        def drained?
          @queue.size.zero?
        end
      end
    end
  end

  Notifications.queue = Notifications::LittleFanout.new
end
