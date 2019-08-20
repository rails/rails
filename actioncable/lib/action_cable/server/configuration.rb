# frozen_string_literal: true

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

        # Require the adapter itself and give useful feedback about
        #   1. Missing adapter gems and
        #   2. Adapter gems' missing dependencies.
        path_to_adapter = "action_cable/subscription_adapter/#{adapter}"
        begin
          require path_to_adapter
        rescue LoadError => e
          # We couldn't require the adapter itself. Raise an exception that
          # points out config typos and missing gems.
          if e.path == path_to_adapter
            # We can assume that a non-builtin adapter was specified, so it's
            # either misspelled or missing from Gemfile.
            raise e.class, "Could not load the '#{adapter}' Action Cable pubsub adapter. Ensure that the adapter is spelled correctly in config/cable.yml and that you've added the necessary adapter gem to your Gemfile.", e.backtrace

          # Bubbled up from the adapter require. Prefix the exception message
          # with some guidance about how to address it and reraise.
          else
            raise e.class, "Error loading the '#{adapter}' Action Cable pubsub adapter. Missing a gem it depends on? #{e.message}", e.backtrace
          end
        end

        adapter = adapter.camelize
        adapter = "PostgreSQL" if adapter == "Postgresql"
        "ActionCable::SubscriptionAdapter::#{adapter}".constantize
      end
    end
  end
end
