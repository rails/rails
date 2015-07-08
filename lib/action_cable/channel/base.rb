module ActionCable
  module Channel
    # The channel provides the basic structure of grouping behavior into logical units when communicating over the websocket connection.
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
    #   class ChatChannel < ApplicationChannel
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
    # Unlike Action Controllers, channels do not follow a REST constraint form for its actions. It's an remote-procedure call model. You can
    # declare any public method on the channel (optionally taking a data argument), and this method is automatically exposed as callable to the client.
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
    # In this example, subscribed/unsubscribed are not callable methods, as they were already declared in ActionCable::Channel::Base, but #appear/away
    # are. #generate_connection_token is also not callable as its a private method. You'll see that appear accepts a data parameter, which it then
    # uses as part of its model call. #away does not, it's simply a trigger action.
    class Base
      include Callbacks
      include PeriodicTimers
      include Streams

      on_subscribe   :subscribed
      on_unsubscribe :unsubscribed

      attr_reader :params, :connection
      delegate :logger, to: :connection

      def initialize(connection, identifier, params = {})
        @connection = connection
        @identifier = identifier
        @params     = params

        subscribe_to_channel
      end

      # Extract the action name from the passed data and process it via the channel. The process will ensure
      # that the action requested is a public method on the channel declared by the user (so not one of the callbacks
      # like #subscribed).
      def perform_action(data)
        action = extract_action(data)

        if processable_action?(action)
          dispatch_action(action, data)
        else
          logger.error "Unable to process #{action_signature(action, data)}"
        end
      end

      # Called by the cable connection when its cut so the channel has a chance to cleanup with callbacks. 
      # This method is not intended to be called directly by the user. Instead, overwrite the #unsubscribed callback.
      def unsubscribe_from_channel
        run_unsubscribe_callbacks
        logger.info "#{self.class.name} unsubscribed"
      end


      protected
        # Called once a consumer has become a subscriber of the channel. Usually the place to setup any streams
        # you want this channel to be sending to the subscriber.
        def subscribed
          # Override in subclasses
        end

        # Called once a consumer has cut its cable connection. Can be used for cleaning up connections or marking
        # people as offline or the like.
        def unsubscribed
          # Override in subclasses
        end
        
        # Transmit a hash of data to the subscriber. The hash will automatically be wrapped in a JSON envelope with 
        # the proper channel identifier marked as the recipient.
        def transmit(data, via: nil)
          logger.info "#{self.class.name} transmitting #{data.inspect}".tap { |m| m << " (via #{via})" if via }
          connection.transmit({ identifier: @identifier, message: data }.to_json)
        end


      private
        def subscribe_to_channel
          logger.info "#{self.class.name} subscribing"
          run_subscribe_callbacks
        end


        def extract_action(data)
          (data['action'].presence || :receive).to_sym
        end

        def processable_action?(action)
          self.class.instance_methods(false).include?(action)
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
            if (arguments = data.except('action')).any?
              signature << "(#{arguments.inspect})"
            end
          end
        end


        def run_subscribe_callbacks
          self.class.on_subscribe_callbacks.each { |callback| send(callback) }
        end

        def run_unsubscribe_callbacks
          self.class.on_unsubscribe_callbacks.each { |callback| send(callback) }
        end
    end
  end
end
