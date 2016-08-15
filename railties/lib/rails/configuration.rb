require "active_support/ordered_options"
require "active_support/core_ext/object"
require "rails/paths"
require "rails/rack"

module Rails
  module Configuration
    # MiddlewareStackProxy is a proxy for the Rails middleware stack that allows
    # you to configure middlewares in your application. It works basically as a
    # command recorder, saving each command to be applied after initialization
    # over the default middleware stack, so you can add, swap, or remove any
    # middleware in Rails.
    #
    # You can add your own middlewares by using the +config.middleware.use+ method:
    #
    #     config.middleware.use Magical::Unicorns
    #
    # This will put the <tt>Magical::Unicorns</tt> middleware on the end of the stack.
    # You can use +insert_before+ if you wish to add a middleware before another:
    #
    #     config.middleware.insert_before Rack::Head, Magical::Unicorns
    #
    # There's also +insert_after+ which will insert a middleware after another:
    #
    #     config.middleware.insert_after Rack::Head, Magical::Unicorns
    #
    # Middlewares can also be completely swapped out and replaced with others:
    #
    #     config.middleware.swap ActionDispatch::Flash, Magical::Unicorns
    #
    # And finally they can also be removed from the stack completely:
    #
    #     config.middleware.delete ActionDispatch::Flash
    #
    class MiddlewareStackProxy
      def initialize(operations = [], delete_operations = [])
        @operations = operations
        @delete_operations = delete_operations
      end

      def insert_before(*args, &block)
        @operations << [__method__, args, block]
      end

      alias :insert :insert_before

      def insert_after(*args, &block)
        @operations << [__method__, args, block]
      end

      def swap(*args, &block)
        @operations << [__method__, args, block]
      end

      def use(*args, &block)
        @operations << [__method__, args, block]
      end

      def delete(*args, &block)
        @delete_operations << [__method__, args, block]
      end

      def unshift(*args, &block)
        @operations << [__method__, args, block]
      end

      def merge_into(other) #:nodoc:
        (@operations + @delete_operations).each do |operation, args, block|
          other.send(operation, *args, &block)
        end

        other
      end

      def +(other) # :nodoc:
        MiddlewareStackProxy.new(@operations + other.operations, @delete_operations + other.delete_operations)
      end

      protected
        def operations
          @operations
        end

        def delete_operations
          @delete_operations
        end
    end

    class Generators #:nodoc:
      attr_accessor :aliases, :options, :templates, :fallbacks, :colorize_logging, :api_only
      attr_reader :hidden_namespaces

      def initialize
        @aliases = Hash.new { |h,k| h[k] = {} }
        @options = Hash.new { |h,k| h[k] = {} }
        @fallbacks = {}
        @templates = []
        @colorize_logging = true
        @api_only = false
        @hidden_namespaces = []
      end

      def initialize_copy(source)
        @aliases = @aliases.deep_dup
        @options = @options.deep_dup
        @fallbacks = @fallbacks.deep_dup
        @templates = @templates.dup
      end

      def hide_namespace(namespace)
        @hidden_namespaces << namespace
      end

      def method_missing(method, *args)
        method = method.to_s.sub(/=$/, "").to_sym

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
  end
end
