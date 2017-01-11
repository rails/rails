module ActionCable
  module Client
    # Makes it possible for the RemoteConnection to disconnect a specific connection.
    module InternalChannel
      extend ActiveSupport::Concern

      INTERNAL_CHANNEL_ID = "_internal"

      private
        def internal_channel
          "action_cable/#{identifier}"
        end

        def subscribe_to_internal_channel
          if identifier.present?
            callback = -> (message) { process_internal_message decode(message) }
            streams.add(INTERNAL_CHANNEL_ID, internal_channel, callback) do
              logger.info "Registered connection (#{connection_identifier})"
            end
          end
        end

        def unsubscribe_from_internal_channel
          streams.remove_all INTERNAL_CHANNEL_ID
        end

        def process_internal_message(message)
          case message["type"]
          when "disconnect"
            logger.info "Removing connection (#{connection_identifier})"
            connection.close
          end
        rescue Exception => e
          logger.error "There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")

          close
        end
    end
  end
end
