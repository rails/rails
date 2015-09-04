require 'active_support/core_ext/hash/indifferent_access'

module ActionCable
  module Server
    # An instance of this configuration object is available via ActionCable.server.config, which allows you to tweak the configuration points
    # in a Rails config initializer.
    class Configuration
      attr_accessor :logger, :log_tags
      attr_accessor :connection_class, :worker_pool_size
      attr_accessor :redis_path, :channels_path
      attr_accessor :disable_request_forgery_protection, :allowed_request_origins
      attr_accessor :url

      def initialize
        @logger   = Rails.logger
        @log_tags = []

        @connection_class  = ApplicationCable::Connection
        @worker_pool_size  = 100

        @redis_path    = Rails.root.join('config/redis/cable.yml')
        @channels_path = Rails.root.join('app/channels')

        @disable_request_forgery_protection = false
      end

      def log_to_stdout
        console = ActiveSupport::Logger.new($stdout)
        console.formatter = @logger.formatter
        console.level = @logger.level

        @logger.extend(ActiveSupport::Logger.broadcast(console))
      end

      def channel_paths
        @channels ||= Dir["#{channels_path}/**/*_channel.rb"]
      end

      def channel_class_names
        @channel_class_names ||= channel_paths.collect do |channel_path|
          Pathname.new(channel_path).basename.to_s.split('.').first.camelize
        end
      end

      def redis
        @redis ||= config_for(redis_path).with_indifferent_access
      end

      private
        # FIXME: Extract this from Rails::Application in a way it can be used here.
        def config_for(path)
          if path.exist?
            require "yaml"
            require "erb"
            (YAML.load(ERB.new(path.read).result) || {})[Rails.env] || {}
          else
            raise "Could not load configuration. No such file - #{path}"
          end
        rescue Psych::SyntaxError => e
          raise "YAML syntax error occurred while parsing #{path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{e.message}"
        end
    end
  end
end

