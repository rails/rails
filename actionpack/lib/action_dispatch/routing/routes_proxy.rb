require 'active_support/core_ext/array/extract_options'

module ActionDispatch
  module Routing
    class RoutesProxy #:nodoc:
      include ActionDispatch::Routing::UrlFor

      attr_accessor :scope, :routes
      alias :_routes :routes

      def initialize(routes, scope, helpers)
        @routes, @scope = routes, scope
        @helpers = helpers
      end

      def url_options
        scope.send(:_with_routes, routes) do
          scope.url_options
        end
      end

      def respond_to?(method, include_private = false)
        super || @helpers.respond_to?(method)
      end

      def method_missing(method, *args)
        if @helpers.respond_to?(method)
          self.class.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{method}(*args)
              options = args.extract_options!
              args << url_options.merge((options || {}).symbolize_keys)
              @helpers.#{method}(*args)
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
