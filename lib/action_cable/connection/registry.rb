module ActionCable
  module Connection
    module Registry
      extend ActiveSupport::Concern

      included do
        class_attribute :identifiers
        self.identifiers = Set.new
      end

      module ClassMethods
        def identified_by(*identifiers)
          self.identifiers += identifiers
        end
      end

      def register_connection
        if connection_identifier.present?
          callback = -> (message) { process_registry_message(message) }
          @_internal_redis_subscriptions ||= []
          @_internal_redis_subscriptions << [ internal_redis_channel, callback ]

          pubsub.subscribe(internal_redis_channel, &callback)
          logger.info "[ActionCable] Registered connection (#{connection_identifier})"
        end
      end

      def internal_redis_channel
        "action_cable/#{connection_identifier}"
      end

      def connection_identifier
        @connection_identifier ||= connection_gid identifiers.map { |id| instance_variable_get("@#{id}")}
      end

      def connection_gid(ids)
        ids.map {|o| o.to_global_id.to_s }.sort.join(":")
      end

      def cleanup_internal_redis_subscriptions
        if @_internal_redis_subscriptions.present?
          @_internal_redis_subscriptions.each { |channel, callback| pubsub.unsubscribe_proc(channel, callback) }
        end
      end

      private
        def process_registry_message(message)
          message = ActiveSupport::JSON.decode(message)

          case message['type']
          when 'disconnect'
            logger.info "[ActionCable] Removing connection (#{connection_identifier})"
            @websocket.close
          end
        rescue Exception => e
          logger.error "[ActionCable] There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")

          handle_exception
        end

    end
  end
end
