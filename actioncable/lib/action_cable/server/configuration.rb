module ActionCable
  module Server
    # An instance of this configuration object is available via ActionCable.server.config, which allows you to tweak the configuration points
    # in a Rails config initializer.
    class Configuration
      attr_accessor :logger, :log_tags
      attr_accessor :connection_class, :worker_pool_size
      attr_accessor :channels_path
      attr_accessor :disable_request_forgery_protection, :allowed_request_origins
      attr_accessor :cable, :url

      def initialize
        @log_tags = []

        @connection_class  = ApplicationCable::Connection
        @worker_pool_size  = 100

        @channels_path = Rails.root.join('app/channels')

        @disable_request_forgery_protection = false
      end

      def channel_paths
        @channels ||= Dir["#{channels_path}/**/*_channel.rb"]
      end

      def channel_class_names
        @channel_class_names ||= channel_paths.collect do |channel_path|
          Pathname.new(channel_path).basename.to_s.split('.').first.camelize
        end
      end

      # Returns constant of subscription adapter specified in config/cable.yml
      # If the adapter cannot be found, this will default to the Redis adapter
      def subscription_adapter
        # Defaults to redis if no adapter is set
        adapter = cable.fetch('adapter') { 'redis' }
        adapter.camelize
        adapter = 'PostgreSQL' if adapter == 'Postgresql'
        "ActionCable::SubscriptionAdapter::#{adapter}".constantize
      end
    end
  end
end

