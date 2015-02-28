require 'active_support/core_ext/array/extract_options'

module ActionDispatch
  module Routing
    class RoutesProxy #:nodoc:
      include ActionDispatch::Routing::UrlFor

      attr_accessor :scope, :routes
      alias :_routes :routes

      def initialize(routes, scope, helpers)
        @routes, @scope = routes, scope
        @controller = Class.new {
          attr_reader :context
          def initialize(context, routes, helpers)
            @context = context
            @_routes = routes
            @helpers = helpers
          end

          include routes.url_helpers
        }.new(scope_context, routes, helpers)
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
        super || @controller.respond_to?(method)
      end

      def method_missing(method, *args)
        if @controller.respond_to?(method)
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
