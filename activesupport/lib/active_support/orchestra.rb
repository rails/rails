require 'thread'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  # Orchestra provides an instrumentation API for Ruby. To instrument an action
  # in Ruby you just need to:
  #
  #   ActiveSupport::Orchestra.instrument(:render, :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  # Those actions are consumed by listeners. A listener is anything that responds
  # to push. You can even register an array:
  #
  #   @listener = []
  #   ActiveSupport::Orchestra.register @listener
  #
  #   ActiveSupport::Orchestra.instrument(:render, :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  #   event           #=> ActiveSupport::Orchestra::Event
  #   event.name      #=> :render
  #   event.duration  #=> 10 (in miliseconds)
  #   event.result    #=> "Foo"
  #   event.payload   #=> { :extra => :information }
  #
  # Orchestra ships with a default listener implementation which puts events in
  # a stream and consume them in a Thread. This implementation is thread safe
  # and is available at ActiveSupport::Orchestra::Listener.
  #
  module Orchestra
    mattr_accessor :queue

    class << self
      delegate :instrument, :to => :instrumenter

      def instrumenter
        Thread.current[:orchestra_instrumeter] ||= Instrumenter.new(publisher)
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
        @stack = []
      end

      def instrument(name, payload=nil)
        event = Event.new(name, @stack.last, payload)
        @stack << event
        event.result = yield
        event
      ensure
        event.finish!
        @stack.pop
        @publisher.publish(event)
      end
    end

    class Publisher
      def initialize(queue)
        @queue = queue
      end

      def publish(event)
        @queue.publish(event)
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
        @queue.subscribe(@pattern) do |event|
          yield event
        end
      end
    end

    class Event
      attr_reader :name, :time, :duration, :parent, :thread_id, :payload
      attr_accessor :result

      def initialize(name, parent=nil, payload=nil)
        @name      = name
        @time      = Time.now
        @thread_id = Thread.current.object_id
        @parent    = parent
        @payload   = payload
      end

      def finish!
        @duration = 1000 * (Time.now.to_f - @time.to_f)
      end
    end

    # This is a default queue implementation that ships with Orchestra. It
    # consumes events in a thread and publish them to all registered subscribers.
    #
    class LittleFanout
      def initialize
        @listeners, @stream = [], []

        @thread = Thread.new do
          loop do
            (event = @stream.shift) ? consume(event) : Thread.stop
          end
        end
      end

      def publish(event)
        @stream.push(event)
        @thread.run
      end

      def subscribe(pattern=nil, &block)
        @listeners << Listener.new(pattern, &block)
      end

      def consume(event)
        @listeners.each { |l| l.publish(event) }
      end

      class Listener
        def initialize(pattern, &block)
          @pattern = pattern
          @subscriber = block
        end

        def publish(event)
          unless @pattern && event.name.to_s !~ @pattern
            @subscriber.call(event)
          end
        end
      end
    end
  end

  Orchestra.queue = Orchestra::LittleFanout.new
end
