# frozen_string_literal: true

require "active_support/notifications/instrumenter"
require "active_support/notifications/fanout"

module ActiveSupport
  # = \Notifications
  #
  # +ActiveSupport::Notifications+ provides an instrumentation API for
  # Ruby.
  #
  # == Instrumenters
  #
  # To instrument an event you just need to do:
  #
  #   ActiveSupport::Notifications.instrument('render', extra: :information) do
  #     render plain: 'Foo'
  #   end
  #
  # That first executes the block and then notifies all subscribers once done.
  #
  # In the example above +render+ is the name of the event, and the rest is called
  # the _payload_. The payload is a mechanism that allows instrumenters to pass
  # extra information to subscribers. Payloads consist of a hash whose contents
  # are arbitrary and generally depend on the event.
  #
  # == Subscribers
  #
  # You can consume those events and the information they provide by registering
  # a subscriber.
  #
  #   ActiveSupport::Notifications.subscribe('render') do |event|
  #     event.name          # => "render"
  #     event.duration      # => 10 (in milliseconds)
  #     event.payload       # => { extra: :information }
  #     event.allocations   # => 1826 (objects)
  #   end
  #
  # +Event+ objects record CPU time and allocations. If you don't need this
  # it's also possible to pass a block that accepts five arguments:
  #
  #   ActiveSupport::Notifications.subscribe('render') do |name, start, finish, id, payload|
  #     name    # => String, name of the event (such as 'render' from above)
  #     start   # => Time, when the instrumented block started execution
  #     finish  # => Time, when the instrumented block ended execution
  #     id      # => String, unique ID for the instrumenter that fired the event
  #     payload # => Hash, the payload
  #   end
  #
  # Here, the +start+ and +finish+ values represent wall-clock time. If you are
  # concerned about accuracy, you can register a monotonic subscriber.
  #
  #   ActiveSupport::Notifications.monotonic_subscribe('render') do |name, start, finish, id, payload|
  #     name    # => String, name of the event (such as 'render' from above)
  #     start   # => Float, monotonic time when the instrumented block started execution
  #     finish  # => Float, monotonic time when the instrumented block ended execution
  #     id      # => String, unique ID for the instrumenter that fired the event
  #     payload # => Hash, the payload
  #   end
  #
  # For instance, let's store all "render" events in an array:
  #
  #   events = []
  #
  #   ActiveSupport::Notifications.subscribe('render') do |event|
  #     events << event
  #   end
  #
  # That code returns right away, you are just subscribing to "render" events.
  # The block is saved and will be called whenever someone instruments "render":
  #
  #   ActiveSupport::Notifications.instrument('render', extra: :information) do
  #     render plain: 'Foo'
  #   end
  #
  #   event = events.first
  #   event.name          # => "render"
  #   event.duration      # => 10 (in milliseconds)
  #   event.payload       # => { extra: :information }
  #   event.allocations   # => 1826 (objects)
  #
  # If an exception happens during that particular instrumentation the payload will
  # have a key <tt>:exception</tt> with an array of two elements as value: a string with
  # the name of the exception class, and the exception message.
  # The <tt>:exception_object</tt> key of the payload will have the exception
  # itself as the value:
  #
  #   event.payload[:exception]         # => ["ArgumentError", "Invalid value"]
  #   event.payload[:exception_object]  # => #<ArgumentError: Invalid value>
  #
  # As the earlier example depicts, the class ActiveSupport::Notifications::Event
  # is able to take the arguments as they come and provide an object-oriented
  # interface to that data.
  #
  # It is also possible to pass an object which responds to <tt>call</tt> method
  # as the second parameter to the <tt>subscribe</tt> method instead of a block:
  #
  #   module ActionController
  #     class PageRequest
  #       def call(name, started, finished, unique_id, payload)
  #         Rails.logger.debug ['notification:', name, started, finished, unique_id, payload].join(' ')
  #       end
  #     end
  #   end
  #
  #   ActiveSupport::Notifications.subscribe('process_action.action_controller', ActionController::PageRequest.new)
  #
  # resulting in the following output within the logs including a hash with the payload:
  #
  #   notification: process_action.action_controller 2012-04-13 01:08:35 +0300 2012-04-13 01:08:35 +0300 af358ed7fab884532ec7 {
  #      controller: "Devise::SessionsController",
  #      action: "new",
  #      params: {"action"=>"new", "controller"=>"devise/sessions"},
  #      format: :html,
  #      method: "GET",
  #      path: "/login/sign_in",
  #      status: 200,
  #      view_runtime: 279.3080806732178,
  #      db_runtime: 40.053
  #    }
  #
  # You can also subscribe to all events whose name matches a certain regexp:
  #
  #   ActiveSupport::Notifications.subscribe(/render/) do |*args|
  #     ...
  #   end
  #
  # and even pass no argument to <tt>subscribe</tt>, in which case you are subscribing
  # to all events.
  #
  # == Temporary Subscriptions
  #
  # Sometimes you do not want to subscribe to an event for the entire life of
  # the application. There are two ways to unsubscribe.
  #
  # WARNING: The instrumentation framework is designed for long-running subscribers,
  # use this feature sparingly because it wipes some internal caches and that has
  # a negative impact on performance.
  #
  # === Subscribe While a Block Runs
  #
  # You can subscribe to some event temporarily while some block runs. For
  # example, in
  #
  #   callback = lambda {|event| ... }
  #   ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
  #     ...
  #   end
  #
  # the callback will be called for all "sql.active_record" events instrumented
  # during the execution of the block. The callback is unsubscribed automatically
  # after that.
  #
  # To record +started+ and +finished+ values with monotonic time,
  # specify the optional <tt>:monotonic</tt> option to the
  # <tt>subscribed</tt> method. The <tt>:monotonic</tt> option is set
  # to +false+ by default.
  #
  #   callback = lambda {|name, started, finished, unique_id, payload| ... }
  #   ActiveSupport::Notifications.subscribed(callback, "sql.active_record", monotonic: true) do
  #     ...
  #   end
  #
  # === Manual Unsubscription
  #
  # The +subscribe+ method returns a subscriber object:
  #
  #   subscriber = ActiveSupport::Notifications.subscribe("render") do |event|
  #     ...
  #   end
  #
  # To prevent that block from being called anymore, just unsubscribe passing
  # that reference:
  #
  #   ActiveSupport::Notifications.unsubscribe(subscriber)
  #
  # You can also unsubscribe by passing the name of the subscriber object. Note
  # that this will unsubscribe all subscriptions with the given name:
  #
  #   ActiveSupport::Notifications.unsubscribe("render")
  #
  # Subscribers using a regexp or other pattern-matching object will remain subscribed
  # to all events that match their original pattern, unless those events match a string
  # passed to +unsubscribe+:
  #
  #   subscriber = ActiveSupport::Notifications.subscribe(/render/) { }
  #   ActiveSupport::Notifications.unsubscribe('render_template.action_view')
  #   subscriber.matches?('render_template.action_view') # => false
  #   subscriber.matches?('render_partial.action_view') # => true
  #
  # == Default Queue
  #
  # Notifications ships with a queue implementation that consumes and publishes events
  # to all log subscribers. You can use any queue implementation you want.
  #
  module Notifications
    class << self
      attr_accessor :notifier

      def publish(name, *args)
        notifier.publish(name, *args)
      end

      def publish_event(event) # :nodoc:
        notifier.publish_event(event)
      end

      def instrument(name, payload = {})
        if notifier.listening?(name)
          instrumenter.instrument(name, payload) { yield payload if block_given? }
        else
          yield payload if block_given?
        end
      end

      # Subscribe to a given event name with the passed +block+.
      #
      # You can subscribe to events by passing a String to match exact event
      # names, or by passing a Regexp to match all events that match a pattern.
      #
      # If the block passed to the method only takes one argument,
      # it will yield an +Event+ object to the block:
      #
      #   ActiveSupport::Notifications.subscribe(/render/) do |event|
      #     @event = event
      #   end
      #
      # Otherwise the +block+ will receive five arguments with information
      # about the event:
      #
      #   ActiveSupport::Notifications.subscribe('render') do |name, start, finish, id, payload|
      #     name    # => String, name of the event (such as 'render' from above)
      #     start   # => Time, when the instrumented block started execution
      #     finish  # => Time, when the instrumented block ended execution
      #     id      # => String, unique ID for the instrumenter that fired the event
      #     payload # => Hash, the payload
      #   end
      #
      # Raises an error if invalid event name type is passed:
      #
      #   ActiveSupport::Notifications.subscribe(:render) {|event| ...}
      #   #=> ArgumentError (pattern must be specified as a String, Regexp or empty)
      #
      def subscribe(pattern = nil, callback = nil, &block)
        notifier.subscribe(pattern, callback, monotonic: false, &block)
      end

      # Performs the same functionality as #subscribe, but the +start+ and
      # +finish+ block arguments are in monotonic time instead of wall-clock
      # time. Monotonic time will not jump forward or backward (due to NTP or
      # Daylights Savings). Use +monotonic_subscribe+ when accuracy of time
      # duration is important. For example, computing elapsed time between
      # two events.
      def monotonic_subscribe(pattern = nil, callback = nil, &block)
        notifier.subscribe(pattern, callback, monotonic: true, &block)
      end

      def subscribed(callback, pattern = nil, monotonic: false, &block)
        subscriber = notifier.subscribe(pattern, callback, monotonic: monotonic)
        yield
      ensure
        unsubscribe(subscriber)
      end

      def unsubscribe(subscriber_or_name)
        notifier.unsubscribe(subscriber_or_name)
      end

      def instrumenter
        registry[notifier] ||= Instrumenter.new(notifier)
      end

      private
        def registry
          ActiveSupport::IsolatedExecutionState[:active_support_notifications_registry] ||= {}
        end
    end

    self.notifier = Fanout.new
  end
end
