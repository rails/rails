require 'thread'

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
    @stacked_events = Hash.new { |h,k| h[k] = [] }
    @listeners = []

    def self.instrument(name, payload=nil)
      stack = @stacked_events[Thread.current.object_id]
      event = Event.new(name, stack.last, payload)
      stack << event
      event.result = yield
      event
    ensure
      event.finish!
      stack.delete(event)
      @listeners.each { |s| s.push(event) }
    end

    def self.register(listener)
      @listeners << listener
    end

    def self.unregister(listener)
      @listeners.delete(listener)
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

    class Listener
      attr_reader :mutex, :signaler, :thread

      def initialize
        @mutex, @signaler = Mutex.new, ConditionVariable.new
        @stream = []
        @thread = Thread.new do
          loop do
            (event = @stream.shift) ? consume(event) : wait
          end
        end
      end

      def wait
        @mutex.synchronize do
          @signaler.wait(@mutex)
        end
      end

      def push(event)
        @mutex.synchronize do
          @stream.push(event)
          @signaler.broadcast
        end
      end

      def consume(event)
        raise NotImplementedError
      end
    end
  end
end
