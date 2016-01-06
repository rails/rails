module ActionCable
  module Server
    # An instance of this configuration object is available via ActionCable.server.config, which allows you to tweak the configuration points
    # in a Rails config initializer.
    class Configuration
      attr_accessor :logger, :log_tags
      attr_accessor :connection_class, :worker_pool_size
      attr_accessor :channels_path
      attr_accessor :disable_request_forgery_protection, :allowed_request_origins
      attr_accessor :config_opts, :url

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

      ADAPTER = ActionCable::StorageAdapter

      # Returns constant of storage adapter specified in config/cable.yml
      # If the adapter cannot be found, this will default to the Redis adapter
      def storage_adapter
        # "ActionCable::StorageAdapter::#{adapter.capitalize}"
        adapter = config_opts['adapter']
        adapter_const = "ActionCable::StorageAdapter::#{adapter.capitalize}"

        if Object.const_defined?(adapter_const)
          adapter_const.constantize
        else
          ADAPTER_BASE::Redis
        end
      end
    end
  end
end

