require 'active_support/deprecation'
require 'active_support/ordered_options'
require 'rails/paths'
require 'rails/rack'

module Rails
  module Configuration
    class MiddlewareStackProxy #:nodoc:
      def initialize
        @operations = []
      end

      def insert_before(*args, &block)
        @operations << [:insert_before, args, block]
      end

      alias :insert :insert_before

      def insert_after(*args, &block)
        @operations << [:insert_after, args, block]
      end

      def swap(*args, &block)
        @operations << [:swap, args, block]
      end

      def use(*args, &block)
        @operations << [:use, args, block]
      end

      def delete(*args, &block)
        @operations << [:delete, args, block]
      end

      def merge_into(other)
        @operations.each do |operation, args, block|
          other.send(operation, *args, &block)
        end
        other
      end
    end

    class Generators #:nodoc:
      attr_accessor :aliases, :options, :templates, :fallbacks, :colorize_logging

      def initialize
        @aliases = Hash.new { |h,k| h[k] = {} }
        @options = Hash.new { |h,k| h[k] = {} }
        @fallbacks = {}
        @templates = []
        @colorize_logging = true
      end

      def method_missing(method, *args)
        method = method.to_s.sub(/=$/, '').to_sym

        return @options[method] if args.empty?

        if method == :rails || args.first.is_a?(Hash)
          namespace, configuration = method, args.shift
        else
          namespace, configuration = args.shift, args.shift
          namespace = namespace.to_sym if namespace.respond_to?(:to_sym)
          @options[:rails][method] = namespace
        end

        if configuration
          aliases = configuration.delete(:aliases)
          @aliases[namespace].merge!(aliases) if aliases
          @options[namespace].merge!(configuration)
        end
      end
    end

    module Deprecated
      def frameworks(*args)
        raise "config.frameworks in no longer supported. See the generated " \
              "config/boot.rb for steps on how to limit the frameworks that " \
              "will be loaded"
      end
      alias :frameworks= :frameworks

      def view_path=(value)
        ActiveSupport::Deprecation.warn "config.view_path= is deprecated, " <<
          "please do paths.app.views= instead", caller
        paths.app.views = value
      end

      def view_path
        ActiveSupport::Deprecation.warn "config.view_path is deprecated, " <<
          "please do paths.app.views instead", caller
        paths.app.views.to_a.first
      end

      def routes_configuration_file=(value)
        ActiveSupport::Deprecation.warn "config.routes_configuration_file= is deprecated, " <<
          "please do paths.config.routes= instead", caller
        paths.config.routes = value
      end

      def routes_configuration_file
        ActiveSupport::Deprecation.warn "config.routes_configuration_file is deprecated, " <<
          "please do paths.config.routes instead", caller
        paths.config.routes.to_a.first
      end

      def database_configuration_file=(value)
        ActiveSupport::Deprecation.warn "config.database_configuration_file= is deprecated, " <<
          "please do paths.config.database= instead", caller
        paths.config.database = value
      end

      def database_configuration_file
        ActiveSupport::Deprecation.warn "config.database_configuration_file is deprecated, " <<
          "please do paths.config.database instead", caller
        paths.config.database.to_a.first
      end

      def log_path=(value)
        ActiveSupport::Deprecation.warn "config.log_path= is deprecated, " <<
          "please do paths.log= instead", caller
        paths.config.log = value
      end

      def log_path
        ActiveSupport::Deprecation.warn "config.log_path is deprecated, " <<
          "please do paths.log instead", caller
        paths.config.log.to_a.first
      end

      def controller_paths=(value)
        ActiveSupport::Deprecation.warn "config.controller_paths= is deprecated, " <<
          "please do paths.app.controllers= instead", caller
        paths.app.controllers = value
      end

      def controller_paths
        ActiveSupport::Deprecation.warn "config.controller_paths is deprecated, " <<
          "please do paths.app.controllers instead", caller
        paths.app.controllers.to_a.uniq
      end

      def cookie_secret=(value)
        ActiveSupport::Deprecation.warn "config.cookie_secret= is deprecated, " <<
          "please use config.secret_token= instead", caller
        self.secret_token = value
      end

      def cookie_secret
        ActiveSupport::Deprecation.warn "config.cookie_secret is deprecated, " <<
          "please use config.secret_token instead", caller
        self.secret_token
      end
    end
  end
end
