module ActionCable
  module Server
    # An instance of this configuration object is available via ActionCable.server.config, which allows you to tweak Action Cable configuration
    # in a Rails config initializer.
    class Configuration
      attr_accessor :logger, :log_tags
      attr_accessor :connection_class, :worker_pool_size
      attr_accessor :disable_request_forgery_protection, :allowed_request_origins, :allow_same_origin_as_host
      attr_accessor :cable, :url, :mount_path

      def initialize
        @log_tags = []

        @connection_class = -> { ActionCable::Connection::Base }
        @worker_pool_size = 4

        @disable_request_forgery_protection = false
        @allow_same_origin_as_host = true
      end

      # Returns constant of subscription adapter specified in config/cable.yml.
      # If the adapter cannot be found, this will default to the Redis adapter.
      # Also makes sure proper dependencies are required.
      def pubsub_adapter
        adapter = (cable.fetch("adapter") { "redis" })
        path_to_adapter = "action_cable/subscription_adapter/#{adapter}"
        begin
          require path_to_adapter
        rescue Gem::LoadError => e
          raise Gem::LoadError, "Specified '#{adapter}' for Action Cable pubsub adapter, but the gem is not loaded. Add `gem '#{e.name}'` to your Gemfile (and ensure its version is at the minimum required by Action Cable)."
        rescue LoadError => e
          raise LoadError, "Could not load '#{path_to_adapter}'. Make sure that the adapter in config/cable.yml is valid. If you use an adapter other than 'postgresql' or 'redis' add the necessary adapter gem to the Gemfile.", e.backtrace
        end

        adapter = adapter.camelize
        adapter = "PostgreSQL" if adapter == "Postgresql"
        "ActionCable::SubscriptionAdapter::#{adapter}".constantize
      end
    end
  end
end
