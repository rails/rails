require 'active_support/core_ext/array/extract_options'

module ActionDispatch
  module Routing
    class RoutesProxy #:nodoc:
      include ActionDispatch::Routing::UrlFor

      attr_accessor :scope, :routes
      alias :_routes :routes

      Context = Struct.new(:path_parameters, :url_options)

      def initialize(routes, scope)
        @routes, @scope = routes, scope
        context = Context.new(scope_context.path_parameters,
                              scope_context.url_options)
        @controller = Class.new {
          attr_reader :context
          def initialize(context)
            @context = context
          end

          include routes.url_helpers
        }.new(context)
      end

      def url_options
        scope.send(:_with_routes, routes) do
          scope.url_options
        end
      end

      def scope_context
        scope.send(:_with_routes, routes) do
          scope.context
        end
      end

      def respond_to?(method, include_private = false)
        super || routes.url_helpers.respond_to?(method)
      end

      def method_missing(method, *args)
        if routes.url_helpers.respond_to?(method)
          self.class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{method}(*args)
              options = args.extract_options!
              args << (options || {}).symbolize_keys
              @controller.#{method}(*args)
            end
          RUBY
          send(method, *args)
        else
          super
        end
      end
    end
  end
end
