module ActionCable
  module Client
    # For every WebSocket connection the Action Cable server accepts, a Client object will be instantiated. This instance becomes the parent
    # of all of the channel subscriptions that are created from there on. Incoming messages are then routed to these channel subscriptions
    # based on an identifier sent by the Action Cable consumer. The Client itself does not deal with any specific application logic beyond
    # authentication and authorization.
    #
    # Here's a basic example:
    #
    #   module ApplicationCable
    #     class Client < ActionCable::Client::Base
    #       identified_by :current_user
    #
    #       def connect
    #         self.current_user = find_verified_user
    #         logger.add_tags current_user.name
    #       end
    #
    #       def disconnect
    #         # Any cleanup work needed when the cable connection is cut.
    #       end
    #
    #       private
    #         def find_verified_user
    #           User.find_by_identity(cookies.signed[:identity_id]) ||
    #             reject_unauthorized_connection
    #         end
    #     end
    #   end
    #
    # First, we declare that this client's connection can be identified by its current_user. This allows us to later be able to find all connections
    # established for that current_user (and potentially disconnect them). You can declare as many
    # identification indexes as you like. Declaring an identification means that an attr_accessor is automatically set for that key.
    #
    # Second, we rely on the fact that the WebSocket connection is established with the cookies from the domain being sent along. This makes
    # it easy to use signed cookies that were set when logging in via a web interface to authorize the WebSocket connection.
    #
    # Finally, we add a tag to the client-specific logger with the name of the current user to easily distinguish their messages in the log.
    #
    # Pretty simple, eh?
    class Base
      include Authorization
      include Identification
      include InternalChannel

      attr_reader :subscriptions, :streams

      delegate :logger, :request, :cookies, :close, to: :connection

      def initialize(connection, coder: ActiveSupport::JSON)
        @connection = connection
        @coder = coder

        @subscriptions = Subscriptions.new(self)
        @streams = Streams.new(connection)
      end

      def handle_connect
        connect if respond_to?(:connect)
        subscribe_to_internal_channel
        send_welcome_message
      end

      def handle_disconnect
        subscriptions.unsubscribe_from_all
        unsubscribe_from_internal_channel

        disconnect if respond_to?(:disconnect)
      end

      def handle_command(websocket_message)
        command = decode(websocket_message)
        subscriptions.execute_command command
      end

      def transmit(cable_message)
        connection.transmit encode(cable_message)
      end

      def start_periodic_timer(callback, every:)
        connection.server.event_loop.timer every do
          connection.worker_pool.async_exec self, connection: connection, &callback
        end
      end

      private
        attr_reader :connection, :coder

        def send_welcome_message
          # Send welcome message to the internal connection monitor channel.
          # This ensures the connection monitor state is reset after a successful
          # websocket connection.
          transmit type: ActionCable::INTERNAL[:message_types][:welcome]
        end

        def encode(cable_message)
          coder.encode cable_message
        end

        def decode(websocket_message)
          coder.decode websocket_message
        end
    end
  end
end
