# frozen_string_literal: true

require 'rails/configuration'
require 'active_support/core_ext/symbol/starts_ends_with'

module Rails
  class Railtie
    class Configuration
      def initialize
        @@options ||= {}
      end

      # Expose the eager_load_namespaces at "module" level for convenience.
      def self.eager_load_namespaces #:nodoc:
        @@eager_load_namespaces ||= []
      end

      # All namespaces that are eager loaded
      def eager_load_namespaces
        @@eager_load_namespaces ||= []
      end

      # Add files that should be watched for change.
      def watchable_files
        @@watchable_files ||= []
      end

      # Add directories that should be watched for change.
      # The key of the hashes should be directories and the values should
      # be an array of extensions to match in each directory.
      def watchable_dirs
        @@watchable_dirs ||= {}
      end

      # This allows you to modify the application's middlewares from Engines.
      #
      # All operations you run on the app_middleware will be replayed on the
      # application once it is defined and the default_middlewares are
      # created
      def app_middleware
        @@app_middleware ||= Rails::Configuration::MiddlewareStackProxy.new
      end

      # This allows you to modify application's generators from Railties.
      #
      # Values set on app_generators will become defaults for application, unless
      # application overwrites them.
      def app_generators
        @@app_generators ||= Rails::Configuration::Generators.new
        yield(@@app_generators) if block_given?
        @@app_generators
      end

      # First configurable block to run. Called before any initializers are run.
      def before_configuration(&block)
        ActiveSupport.on_load(:before_configuration, yield: true, &block)
      end

      # Third configurable block to run. Does not run if +config.eager_load+
      # set to false.
      def before_eager_load(&block)
        ActiveSupport.on_load(:before_eager_load, yield: true, &block)
      end

      # Second configurable block to run. Called before frameworks initialize.
      def before_initialize(&block)
        ActiveSupport.on_load(:before_initialize, yield: true, &block)
      end

      # Last configurable block to run. Called after frameworks initialize.
      def after_initialize(&block)
        ActiveSupport.on_load(:after_initialize, yield: true, &block)
      end

      # Array of callbacks defined by #to_prepare.
      def to_prepare_blocks
        @@to_prepare_blocks ||= []
      end

      # Defines generic callbacks to run before #after_initialize. Useful for
      # Rails::Railtie subclasses.
      def to_prepare(&blk)
        to_prepare_blocks << blk if blk
      end

      def respond_to?(name, include_private = false)
        super || @@options.key?(name.to_sym)
      end

    private
      def method_missing(name, *args, &blk)
        if name.end_with?('=')
          @@options[:"#{name[0..-2]}"] = args.first
        elsif @@options.key?(name)
          @@options[name]
        else
          super
        end
      end
    end
  end
end
