require 'rails/configuration'

module Rails
  class Railtie
    class Configuration
      class MiddlewareStackProxy
        def initialize
          @operations = []
        end

        def insert_before(*args, &block)
          @operations << [:insert_before, args, block]
        end

        alias insert insert_before

        def insert_after(*args, &block)
          @operations << [:insert_after, args, block]
        end

        def swap(*args, &block)
          @operations << [:swap, args, block]
        end

        def use(*args, &block)
          @operations << [:use, args, block]
        end

        def merge_into(other)
          @operations.each do |operation, args, block|
            other.send(operation, *args, &block)
          end
          other
        end
      end

      def initialize
        @@options ||= {}
      end

      # This allows you to modify the application's middlewares from Engines.
      #
      # All operations you run on the app_middleware will be replayed on the
      # application once it is defined and the default_middlewares are
      # created
      def app_middleware
        @@app_middleware ||= MiddlewareStackProxy.new
      end

      # Holds generators configuration:
      #
      #   config.generators do |g|
      #     g.orm             :datamapper, :migration => true
      #     g.template_engine :haml
      #     g.test_framework  :rspec
      #   end
      #
      # If you want to disable color in console, do:
      #
      #   config.generators.colorize_logging = false
      #
      def generators
        @@generators ||= Rails::Configuration::Generators.new
        if block_given?
          yield @@generators
        else
          @@generators
        end
      end

      def after_initialize(&block)
        ActiveSupport.on_load(:after_initialize, :yield => true, &block)
      end

      def to_prepare_blocks
        @@to_prepare_blocks ||= []
      end

      def to_prepare(&blk)
        to_prepare_blocks << blk if blk
      end

      def respond_to?(name)
        super || @@options.key?(name.to_sym)
      end

    private

      def method_missing(name, *args, &blk)
        if name.to_s =~ /=$/
          @@options[$`.to_sym] = args.first
        elsif @@options.key?(name)
          @@options[name]
        else
          super
        end
      end
    end
  end
end