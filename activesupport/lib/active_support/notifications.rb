module ActiveSupport
  # Notifications provides an instrumentation API for Ruby. To instrument an
  # action in Ruby you just need to do:
  #
  #   ActiveSupport::Notifications.instrument(:render, :extra => :information) do
  #     render :text => "Foo"
  #   end
  #
  # You can consume those events and the information they provide by registering
  # a log subscriber. For instance, let's store all instrumented events in an array:
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
  #   event.name      # => :render
  #   event.duration  # => 10 (in milliseconds)
  #   event.payload   # => { :extra => :information }
  #
  # When subscribing to Notifications, you can pass a pattern, to only consume
  # events that match the pattern:
  #
  #   ActiveSupport::Notifications.subscribe(/render/) do |event|
  #     @render_events << event
  #   end
  #
  # Notifications ships with a queue implementation that consumes and publish events
  # to log subscribers in a thread. You can use any queue implementation you want.
  #
  module Notifications
    autoload :Instrumenter, 'active_support/notifications/instrumenter'
    autoload :Event, 'active_support/notifications/instrumenter'
    autoload :Fanout, 'active_support/notifications/fanout'

    @instrumenters = Hash.new { |h,k| h[k] = notifier.listening?(k) }

    class << self
      attr_accessor :notifier

      def publish(name, *args)
        notifier.publish(name, *args)
      end

      def instrument(name, payload = {})
        if @instrumenters[name]
          instrumenter.instrument(name, payload) { yield payload if block_given? }
        else
          yield payload if block_given?
        end
      end

      def subscribe(*args, &block)
        notifier.subscribe(*args, &block).tap do
          @instrumenters.clear
        end
      end

      def unsubscribe(args)
        notifier.unsubscribe(args)
        @instrumenters.clear
      end

      def instrumenter
        Thread.current[:"instrumentation_#{notifier.object_id}"] ||= Instrumenter.new(notifier)
      end
    end

    self.notifier = Fanout.new
  end
end
