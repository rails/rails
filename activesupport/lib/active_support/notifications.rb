require 'active_support/notifications/instrumenter'
require 'active_support/notifications/fanout'

module ActiveSupport
  # = Notifications
  #
  # <tt>ActiveSupport::Notifications</tt> provides an instrumentation API for
  # Ruby.
  #
  # == Instrumenters
  #
  # To instrument an event you just need to do:
  #
  #   ActiveSupport::Notifications.instrument('render', extra: :information) do
  #     render text: 'Foo'
  #   end
  #
  # That executes the block first and notifies all subscribers once done.
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
  #   ActiveSupport::Notifications.subscribe('render') do |name, start, finish, id, payload|
  #     name    # => String, name of the event (such as 'render' from above)
  #     start   # => Time, when the instrumented block started execution
  #     finish  # => Time, when the instrumented block ended execution
  #     id      # => String, unique ID for this notification
  #     payload # => Hash, the payload
  #   end
  #
  # For instance, let's store all "render" events in an array:
  #
  #   events = []
  #
  #   ActiveSupport::Notifications.subscribe('render') do |*args|
  #     events << ActiveSupport::Notifications::Event.new(*args)
  #   end
  #
  # That code returns right away, you are just subscribing to "render" events.
  # The block is saved and will be called whenever someone instruments "render":
  #
  #   ActiveSupport::Notifications.instrument('render', extra: :information) do
  #     render text: 'Foo'
  #   end
  #
  #   event = events.first
  #   event.name      # => "render"
  #   event.duration  # => 10 (in milliseconds)
  #   event.payload   # => { extra: :information }
  #
  # The block in the <tt>subscribe</tt> call gets the name of the event, start
  # timestamp, end timestamp, a string with a unique identifier for that event
  # (something like "535801666f04d0298cd6"), and a hash with the payload, in
  # that order.
  #
  # If an exception happens during that particular instrumentation the payload will
  # have a key <tt>:exception</tt> with an array of two elements as value: a string with
  # the name of the exception class, and the exception message.
  #
  # As the previous example depicts, the class <tt>ActiveSupport::Notifications::Event</tt>
  # is able to take the arguments as they come and provide an object-oriented
  # interface to that data.
  #
  # It is also possible to pass an object as the second parameter passed to the
  # <tt>subscribe</tt> method instead of a block:
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
  #   callback = lambda {|*args| ... }
  #   ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
  #     ...
  #   end
  #
  # the callback will be called for all "sql.active_record" events instrumented
  # during the execution of the block. The callback is unsubscribed automatically
  # after that.
  #
  # === Manual Unsubscription
  #
  # The +subscribe+ method returns a subscriber object:
  #
  #   subscriber = ActiveSupport::Notifications.subscribe("render") do |*args|
  #     ...
  #   end
  #
  # To prevent that block from being called anymore, just unsubscribe passing
  # that reference:
  #
  #   ActiveSupport::Notifications.unsubscribe(subscriber)
  #
  # == Default Queue
  #
  # Notifications ships with a queue implementation that consumes and publish events
  # to log subscribers in a thread. You can use any queue implementation you want.
  #
  module Notifications

    VALID_NOTIFICATION_TYPES = Set.new([:regular, :filesystem])

    class << self
      attr_accessor :notifiers

      def notifier(type=:regular)
        check_valid_type(type)
        self.notifiers[type] ||= Fanout.new
        self.notifiers[type]
      end

      def notifier=(new_notifier, type=:regular)
        check_valid_type(type)
        self.notifiers[type] = new_notifier
      end

      def publish(name, *args)
        notifier.publish(name, *args)
      end

      def publish_with_type(type, name, *args)
        notifier(type).publish(name, *args)
      end

      def listen_to_filesystem(name, paths, opts={})
        listener = FileSystemChanges::FileSystemListener.new(paths, opts)
        Thread.new do
          listener.start_listening
        end

        Thread.new do
          while true
            while !listener.changed_files.empty?
              changed_file = listener.changed_files.pop()
              publish_with_type(:filesystem, name, {:changed_file => changed_file})
            end
          end
        end

        listener
      end

      def instrument(name, payload = {})
        if notifier.listening?(name)
          instrumenter.instrument(name, payload) { yield payload if block_given? }
        else
          yield payload if block_given?
        end
      end

      def subscribe(*args, &block)
        notifier.subscribe(*args, &block)
      end

      def subscribe_with_type(type, *args, &block)
        notifier(type).subscribe(*args, &block)
      end

      def subscribed(callback, *args, &block)
        subscriber = subscribe(*args, &callback)
        yield
      ensure
        unsubscribe(subscriber)
      end

      def subscribed_with_type(type, callback, *args, &block)
        subscriber = subscribe_with_type(type, *args, &callback)
        yield
      ensure
        unsubscribe_with_type(type, subscriber)
      end

      def unsubscribe(args)
        notifier.unsubscribe(args)
      end

      def unsubscribe_with_type(type, args)
        notifier(type).unsubscribe(args)
      end

      def instrumenter(type=:regular)
        check_valid_type(type)
        Thread.current[:"instrumentation_#{notifier(type).object_id}"] ||= Instrumenter.new(notifier(type))
      end

      private

      def check_valid_type(type)
        if !VALID_NOTIFICATION_TYPES.include?(type)
          raise ArgumentError, "Invalid notification type: #{type}. Valid types are :#{VALID_NOTIFICATION_TYPES.map { |type| type }.join(', :')}"
        end
      end
    end

    self.notifiers = {}
  end
end
