require "set"

module ActionCable
  module Channel
    # The channel provides the basic structure of grouping behavior into logical units when communicating over the WebSocket connection.
    # You can think of a channel like a form of controller, but one that's capable of pushing content to the subscriber in addition to simply
    # responding to the subscriber's direct requests.
    #
    # Channel instances are long-lived. A channel object will be instantiated when the cable consumer becomes a subscriber, and then
    # lives until the consumer disconnects. This may be seconds, minutes, hours, or even days. That means you have to take special care
    # not to do anything silly in a channel that would balloon its memory footprint or whatever. The references are forever, so they won't be released
    # as is normally the case with a controller instance that gets thrown away after every request.
    #
    # Long-lived channels (and connections) also mean you're responsible for ensuring that the data is fresh. If you hold a reference to a user
    # record, but the name is changed while that reference is held, you may be sending stale data if you don't take precautions to avoid it.
    #
    # The upside of long-lived channel instances is that you can use instance variables to keep reference to objects that future subscriber requests
    # can interact with. Here's a quick example:
    #
    #   class ChatChannel < ApplicationCable::Channel
    #     def subscribed
    #       @room = Chat::Room[params[:room_number]]
    #     end
    #
    #     def speak(data)
    #       @room.speak data, user: current_user
    #     end
    #   end
    #
    # The #speak action simply uses the Chat::Room object that was created when the channel was first subscribed to by the consumer when that
    # subscriber wants to say something in the room.
    #
    # == Action processing
    #
    # Unlike subclasses of ActionController::Base, channels do not follow a RESTful
    # constraint form for their actions. Instead, Action Cable operates through a
    # remote-procedure call model. You can declare any public method on the
    # channel (optionally taking a <tt>data</tt> argument), and this method is
    # automatically exposed as callable to the client.
    #
    # Example:
    #
    #   class AppearanceChannel < ApplicationCable::Channel
    #     def subscribed
    #       @connection_token = generate_connection_token
    #     end
    #
    #     def unsubscribed
    #       current_user.disappear @connection_token
    #     end
    #
    #     def appear(data)
    #       current_user.appear @connection_token, on: data['appearing_on']
    #     end
    #
    #     def away
    #       current_user.away @connection_token
    #     end
    #
    #     private
    #       def generate_connection_token
    #         SecureRandom.hex(36)
    #       end
    #   end
    #
    # In this example, the subscribed and unsubscribed methods are not callable methods, as they
    # were already declared in ActionCable::Channel::Base, but <tt>#appear</tt>
    # and <tt>#away</tt> are. <tt>#generate_connection_token</tt> is also not
    # callable, since it's a private method. You'll see that appear accepts a data
    # parameter, which it then uses as part of its model call. <tt>#away</tt>
    # does not, since it's simply a trigger action.
    #
    # Also note that in this example, <tt>current_user</tt> is available because
    # it was marked as an identifying attribute on the connection. All such
    # identifiers will automatically create a delegation method of the same name
    # on the channel instance.
    #
    # == Rejecting subscription requests
    #
    # A channel can reject a subscription request in the #subscribed callback by
    # invoking the #reject method:
    #
    #   class ChatChannel < ApplicationCable::Channel
    #     def subscribed
    #       @room = Chat::Room[params[:room_number]]
    #       reject unless current_user.can_access?(@room)
    #     end
    #   end
    #
    # In this example, the subscription will be rejected if the
    # <tt>current_user</tt> does not have access to the chat room. On the
    # client-side, the <tt>Channel#rejected</tt> callback will get invoked when
    # the server rejects the subscription request.
    class Base
      include Callbacks
      include PeriodicTimers
      include Streams
      include Naming
      include Broadcasting

      attr_reader :params, :connection, :identifier
      delegate :logger, to: :connection

      class << self
        # A list of method names that should be considered actions. This
        # includes all public instance methods on a channel, less
        # any internal methods (defined on Base), adding back in
        # any methods that are internal, but still exist on the class
        # itself.
        #
        # ==== Returns
        # * <tt>Set</tt> - A set of all methods that should be considered actions.
        def action_methods
          @action_methods ||= begin
            # All public instance methods of this class, including ancestors
            methods = (public_instance_methods(true) -
              # Except for public instance methods of Base and its ancestors
              ActionCable::Channel::Base.public_instance_methods(true) +
              # Be sure to include shadowed public instance methods of this class
              public_instance_methods(false)).uniq.map(&:to_s)
            methods.to_set
          end
        end

        protected
          # action_methods are cached and there is sometimes need to refresh
          # them. ::clear_action_methods! allows you to do that, so next time
          # you run action_methods, they will be recalculated.
          def clear_action_methods!
            @action_methods = nil
          end

          # Refresh the cached action_methods when a new action_method is added.
          def method_added(name)
            super
            clear_action_methods!
          end
      end

      def initialize(connection, identifier, params = {})
        @connection = connection
        @identifier = identifier
        @params     = params

        # When a channel is streaming via pubsub, we want to delay the confirmation
        # transmission until pubsub subscription is confirmed.
        #
        # The counter starts at 1 because it's awaiting a call to #subscribe_to_channel
        @defer_subscription_confirmation_counter = Concurrent::AtomicFixnum.new(1)

        @reject_subscription = nil
        @subscription_confirmation_sent = nil

        delegate_connection_identifiers
      end

      # Extract the action name from the passed data and process it via the channel. The process will ensure
      # that the action requested is a public method on the channel declared by the user (so not one of the callbacks
      # like #subscribed).
      def perform_action(data)
        action = extract_action(data)

        if processable_action?(action)
          payload = { channel_class: self.class.name, action: action, data: data }
          ActiveSupport::Notifications.instrument("perform_action.action_cable", payload) do
            dispatch_action(action, data)
          end
        else
          logger.error "Unable to process #{action_signature(action, data)}"
        end
      end

      # This method is called after subscription has been added to the connection
      # and confirms or rejects the subscription.
      def subscribe_to_channel
        run_callbacks :subscribe do
          subscribed
        end

        reject_subscription if subscription_rejected?
        ensure_confirmation_sent
      end

      # Called by the cable connection when it's cut, so the channel has a chance to cleanup with callbacks.
      # This method is not intended to be called directly by the user. Instead, overwrite the #unsubscribed callback.
      def unsubscribe_from_channel # :nodoc:
        run_callbacks :unsubscribe do
          unsubscribed
        end
      end

      protected
        # Called once a consumer has become a subscriber of the channel. Usually the place to setup any streams
        # you want this channel to be sending to the subscriber.
        def subscribed
          # Override in subclasses
        end

        # Called once a consumer has cut its cable connection. Can be used for cleaning up connections or marking
        # users as offline or the like.
        def unsubscribed
          # Override in subclasses
        end

        # Transmit a hash of data to the subscriber. The hash will automatically be wrapped in a JSON envelope with
        # the proper channel identifier marked as the recipient.
        def transmit(data, via: nil)
          logger.info "#{self.class.name} transmitting #{data.inspect.truncate(300)}".tap { |m| m << " (via #{via})" if via }

          payload = { channel_class: self.class.name, data: data, via: via }
          ActiveSupport::Notifications.instrument("transmit.action_cable", payload) do
            connection.transmit identifier: @identifier, message: data
          end
        end

        def ensure_confirmation_sent
          return if subscription_rejected?
          @defer_subscription_confirmation_counter.decrement
          transmit_subscription_confirmation unless defer_subscription_confirmation?
        end

        def defer_subscription_confirmation!
          @defer_subscription_confirmation_counter.increment
        end

        def defer_subscription_confirmation?
          @defer_subscription_confirmation_counter.value > 0
        end

        def subscription_confirmation_sent?
          @subscription_confirmation_sent
        end

        def reject
          @reject_subscription = true
        end

        def subscription_rejected?
          @reject_subscription
        end

      private
        def delegate_connection_identifiers
          connection.identifiers.each do |identifier|
            define_singleton_method(identifier) do
              connection.send(identifier)
            end
          end
        end

        def extract_action(data)
          (data["action"].presence || :receive).to_sym
        end

        def processable_action?(action)
          self.class.action_methods.include?(action.to_s) unless subscription_rejected?
        end

        def dispatch_action(action, data)
          logger.info action_signature(action, data)

          if method(action).arity == 1
            public_send action, data
          else
            public_send action
          end
        end

        def action_signature(action, data)
          "#{self.class.name}##{action}".tap do |signature|
            if (arguments = data.except("action")).any?
              signature << "(#{arguments.inspect})"
            end
          end
        end

        def transmit_subscription_confirmation
          unless subscription_confirmation_sent?
            logger.info "#{self.class.name} is transmitting the subscription confirmation"

            ActiveSupport::Notifications.instrument("transmit_subscription_confirmation.action_cable", channel_class: self.class.name) do
              connection.transmit identifier: @identifier, type: ActionCable::INTERNAL[:message_types][:confirmation]
              @subscription_confirmation_sent = true
            end
          end
        end

        def reject_subscription
          connection.subscriptions.remove_subscription self
          transmit_subscription_rejection
        end

        def transmit_subscription_rejection
          logger.info "#{self.class.name} is transmitting the subscription rejection"

          ActiveSupport::Notifications.instrument("transmit_subscription_rejection.action_cable", channel_class: self.class.name) do
            connection.transmit identifier: @identifier, type: ActionCable::INTERNAL[:message_types][:rejection]
          end
        end
    end
  end
end
