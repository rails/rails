module ActiveRecord
  module ConnectionHandling
    class Registration # :nodoc:
      def self.call
        new.register_connection_handlers
      end

      def register_connection_handlers
        register_default_connection_handler
        register_default_readonly_connection_handler
      end

      private
        def register_default_connection_handler
          ActiveRecord::Base.connection_handlers[:default] ||= ActiveRecord::Base.connection_handler
        end

        def register_default_readonly_connection_handler
          config = ActiveRecord::Base.configurations.replica_configs_for(env_name: DEFAULT_ENV.call.to_s)
          return if config.nil?

          ActiveRecord::Base.connection_handlers[:readonly] ||= register_connection_handler(config)
        end

        def register_connection_handler(config)
          handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new

          config_hash = ActiveRecord::Base.resolve_config_for_connection(config.config)
          handler.establish_connection(config_hash)

          handler
        end
    end
  end
end
