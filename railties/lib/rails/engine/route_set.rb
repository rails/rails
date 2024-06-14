# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/routing/route_set"

module Rails
  class Engine
    class RouteSet < ActionDispatch::Routing::RouteSet # :nodoc:
      class NamedRouteCollection < ActionDispatch::Routing::RouteSet::NamedRouteCollection
        def route_defined?(name)
          Rails.application&.reload_routes_unless_loaded

          super(name)
        end
      end

      def initialize(config = DEFAULT_CONFIG)
        super
        self.named_routes = NamedRouteCollection.new
        named_routes.url_helpers_module.prepend(method_missing_module)
        named_routes.path_helpers_module.prepend(method_missing_module)
      end

      def generate_extras(options, recall = {})
        Rails.application&.reload_routes_unless_loaded

        super(options, recall)
      end

      private
        def method_missing_module
          @method_missing_module ||= Module.new do
            private
              def method_missing(method_name, *args, &block)
                if Rails.application&.reload_routes_unless_loaded
                  public_send(method_name, *args, &block)
                else
                  super(method_name, *args, &block)
                end
              end

              def respond_to_missing?(method_name, *args)
                if Rails.application&.reload_routes_unless_loaded
                  respond_to?(method_name, *args)
                else
                  super(method_name, *args)
                end
              end
          end
        end
    end
  end
end
