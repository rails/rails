require 'active_support/deprecation'
require 'active_support/ordered_options'
require 'active_support/core_ext/hash/deep_dup'
require 'rails/paths'
require 'rails/rack'

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
    # This will put the +Magical::Unicorns+ middleware on the end of the stack.
    # You can use +insert_before+ if you wish to add a middleware before another:
    #
    #     config.middleware.insert_before ActionDispatch::Head, Magical::Unicorns
    #
    # There's also +insert_after+ which will insert a middleware after another:
    #
    #     config.middleware.insert_after ActionDispatch::Head, Magical::Unicorns
    #
    # Middlewares can also be completely swapped out and replaced with others:
    #
    #     config.middleware.swap ActionDispatch::BestStandardsSupport, Magical::Unicorns
    #
    # And finally they can also be removed from the stack completely:
    #
    #     config.middleware.delete ActionDispatch::BestStandardsSupport
    #
    # In addition to these methods to handle the stack, if your application is
    # going to be used as an API endpoint only, the middleware stack can be
    # configured like this:
    #
    #     config.middleware.http_only!
    #
    # By doing this, Rails will create a smaller middleware stack, by not adding
    # some middlewares that are usually useful for browser access only, such as
    # Cookies, Session and Flash, BestStandardsSupport, and MethodOverride. You
    # can always add any of them later manually if you want.
    class MiddlewareStackProxy
      attr_reader :http_only
      alias       :http_only? :http_only

      def initialize
        @operations = []
        @http_only  = false
      end

      def http_only!
        @http_only = true
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

      def merge_into(other) #:nodoc:
        @operations.each do |operation, args, block|
          other.send(operation, *args, &block)
        end
        other
      end
    end

    class Generators #:nodoc:
      attr_accessor :aliases, :options, :templates, :fallbacks, :colorize_logging
      attr_reader :hidden_namespaces

      attr_reader :http_only
      alias       :http_only? :http_only

      def initialize
        @aliases = Hash.new { |h,k| h[k] = {} }
        @options = Hash.new { |h,k| h[k] = {} }
        @fallbacks = {}
        @templates = []
        @colorize_logging = true
        @hidden_namespaces = []
        @http_only = false
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

      def http_only!
        @http_only = true
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
  end
end
