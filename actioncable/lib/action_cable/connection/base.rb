# frozen_string_literal: true

# :markup: markdown

require "active_support/rescuable"

module ActionCable
  module Connection
    # # Action Cable Connection Base
    #
    # For every WebSocket connection the Action Cable server accepts, a Connection
    # object will be instantiated. This instance becomes the parent of all of the
    # channel subscriptions that are created from there on. Incoming messages are
    # then routed to these channel subscriptions based on an identifier sent by the
    # Action Cable consumer. The Connection itself does not deal with any specific
    # application logic beyond authentication and authorization.
    #
    # Here's a basic example:
    #
    #     module ApplicationCable
    #       class Connection < ActionCable::Connection::Base
    #         identified_by :current_user
    #
    #         def connect
    #           self.current_user = find_verified_user
    #           logger.add_tags current_user.name
    #         end
    #
    #         def disconnect
    #           # Any cleanup work needed when the cable connection is cut.
    #         end
    #
    #         private
    #           def find_verified_user
    #             User.find_by_identity(cookies.encrypted[:identity_id]) ||
    #               reject_unauthorized_connection
    #           end
    #       end
    #     end
    #
    # First, we declare that this connection can be identified by its current_user.
    # This allows us to later be able to find all connections established for that
    # current_user (and potentially disconnect them). You can declare as many
    # identification indexes as you like. Declaring an identification means that an
    # attr_accessor is automatically set for that key.
    #
    # Second, we rely on the fact that the WebSocket connection is established with
    # the cookies from the domain being sent along. This makes it easy to use signed
    # cookies that were set when logging in via a web interface to authorize the
    # WebSocket connection.
    #
    # Finally, we add a tag to the connection-specific logger with the name of the
    # current user to easily distinguish their messages in the log.
    #
    class Base
      include Identification
      include InternalChannel
      include Authorization
      include Callbacks
      include ActiveSupport::Rescuable

      attr_reader :subscriptions, :logger
      private attr_reader :server, :socket

      delegate :pubsub, :config, to: :server
      delegate :env, :request, :protocol, :perform_work, to: :socket, allow_nil: true

      def initialize(server, socket)
        @server = server
        @socket = socket

        @logger = socket.logger
        @subscriptions  = Subscriptions.new(self)

        @_internal_subscriptions = nil

        @started_at = Time.now
      end

      # This method is called every time an Action Cable client establishes an underlying connection.
      # Override it in your class to define authentication logic and
      # populate connection identifiers.
      def connect
      end

      # This method is called every time an Action Cable client disconnects.
      # Override it in your class to cleanup the relevant application state (e.g., presence, online counts, etc.)
      def disconnect
      end

      def handle_open
        connect
        subscribe_to_internal_channel
        send_welcome_message
      rescue ActionCable::Connection::Authorization::UnauthorizedError
        close(reason: ActionCable::INTERNAL[:disconnect_reasons][:unauthorized], reconnect: false)
      end

      def handle_close
        subscriptions.unsubscribe_from_all
        unsubscribe_from_internal_channel

        disconnect
      end

      def handle_channel_command(payload)
        run_callbacks :command do
          subscriptions.execute_command payload
        end
      end

      alias_method :handle_incoming, :handle_channel_command

      def transmit(data) # :nodoc:
        socket.transmit(data)
      end

      # Close the connection.
      def close(reason: nil, reconnect: true)
        transmit(
          type: ActionCable::INTERNAL[:message_types][:disconnect],
          reason: reason,
          reconnect: reconnect
        )
        socket.close
      end

      # Return a basic hash of statistics for the connection keyed with `identifier`,
      # `started_at`, `subscriptions`, and `request_id`. This can be returned by a
      # health check against the connection.
      def statistics
        {
          identifier: connection_identifier,
          started_at: @started_at,
          subscriptions: subscriptions.identifiers,
          request_id: env["action_dispatch.request_id"]
        }
      end

      def beat
        transmit type: ActionCable::INTERNAL[:message_types][:ping], message: Time.now.to_i
      end

      def inspect # :nodoc:
        "#<#{self.class.name}:#{'%#016x' % (object_id << 1)}>"
      end

      private
        # The cookies of the request that initiated the WebSocket connection. Useful for performing authorization checks.
        def cookies # :doc:
          request.cookie_jar
        end

        def send_welcome_message
          # Send welcome message to the internal connection monitor channel. This ensures
          # the connection monitor state is reset after a successful websocket connection.
          transmit type: ActionCable::INTERNAL[:message_types][:welcome]
        end
    end
  end
end

ActiveSupport.run_load_hooks(:action_cable_connection, ActionCable::Connection::Base)
