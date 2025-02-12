# frozen_string_literal: true

require "active_support/notifications"

module ActiveSupport
  # = Active Support \Subscriber
  #
  # +ActiveSupport::Subscriber+ is an object set to consume
  # ActiveSupport::Notifications. The subscriber dispatches notifications to
  # a registered object based on its given namespace.
  #
  # An example would be an Active Record subscriber responsible for collecting
  # statistics about queries:
  #
  #   module ActiveRecord
  #     class StatsSubscriber < ActiveSupport::Subscriber
  #       attach_to :active_record
  #
  #       def sql(event)
  #         Statsd.timing("sql.#{event.payload[:name]}", event.duration)
  #       end
  #     end
  #   end
  #
  # After configured, whenever a <tt>"sql.active_record"</tt> notification is
  # published, it will properly dispatch the event
  # (ActiveSupport::Notifications::Event) to the +sql+ method.
  #
  # We can detach a subscriber as well:
  #
  #   ActiveRecord::StatsSubscriber.detach_from(:active_record)
  class Subscriber
    class << self
      # Attach the subscriber to a namespace.
      def attach_to(namespace, subscriber = new, notifier = ActiveSupport::Notifications, inherit_all: false)
        @namespace  = namespace
        @subscriber = subscriber
        @notifier   = notifier
        @inherit_all = inherit_all

        subscribers << subscriber

        # Add event subscribers for all existing methods on the class.
        fetch_public_methods(subscriber, inherit_all).each do |event|
          add_event_subscriber(event)
        end
      end

      # Detach the subscriber from a namespace.
      def detach_from(namespace, notifier = ActiveSupport::Notifications)
        @namespace  = namespace
        @subscriber = find_attached_subscriber
        @notifier   = notifier

        return unless subscriber

        subscribers.delete(subscriber)

        # Remove event subscribers of all existing methods on the class.
        fetch_public_methods(subscriber, true).each do |event|
          remove_event_subscriber(event)
        end

        # Reset notifier so that event subscribers will not add for new methods added to the class.
        @notifier = nil
      end

      # Adds event subscribers for all new methods added to the class.
      def method_added(event)
        super
        # Only public methods are added as subscribers, and only if a notifier
        # has been set up. This means that subscribers will only be set up for
        # classes that call #attach_to.
        if public_method_defined?(event) && notifier
          add_event_subscriber(event)
        end
      end

      def subscribers
        @@subscribers ||= []
      end

      private
        attr_reader :subscriber, :notifier, :namespace

        def add_event_subscriber(event) # :doc:
          return if invalid_event?(event)

          pattern = prepare_pattern(event)

          # Don't add multiple subscribers (e.g. if methods are redefined).
          return if pattern_subscribed?(pattern)

          subscriber.patterns[pattern] = notifier.subscribe(pattern, subscriber)
        end

        def remove_event_subscriber(event) # :doc:
          return if invalid_event?(event)

          pattern = prepare_pattern(event)

          return unless pattern_subscribed?(pattern)

          notifier.unsubscribe(subscriber.patterns[pattern])
          subscriber.patterns.delete(pattern)
        end

        def find_attached_subscriber
          subscribers.find { |attached_subscriber| attached_subscriber.instance_of?(self) }
        end

        def invalid_event?(event)
          %i{ start finish }.include?(event.to_sym)
        end

        def prepare_pattern(event)
          "#{event}.#{namespace}"
        end

        def pattern_subscribed?(pattern)
          subscriber.patterns.key?(pattern)
        end

        def fetch_public_methods(subscriber, inherit_all)
          subscriber.public_methods(inherit_all) - Subscriber.public_instance_methods(true)
        end
    end

    attr_reader :patterns # :nodoc:

    def initialize
      @patterns  = {}
      super
    end

    def call(event)
      method = event.name[0, event.name.index(".")]
      send(method, event)
    end

    def publish_event(event) # :nodoc:
      method = event.name[0, event.name.index(".")]
      send(method, event)
    end
  end
end
