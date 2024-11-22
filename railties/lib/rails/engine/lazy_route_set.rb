# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/routing/route_set"

module Rails
  class Engine
    class LazyRouteSet < ActionDispatch::Routing::RouteSet # :nodoc:
      class NamedRouteCollection < ActionDispatch::Routing::RouteSet::NamedRouteCollection
        def route_defined?(name)
          Rails.application&.reload_routes_unless_loaded
          super
        end
      end

      module ProxyUrlHelpers
        def url_for(options)
          Rails.application&.reload_routes_unless_loaded
          super
        end

        def full_url_for(options)
          Rails.application&.reload_routes_unless_loaded
          super
        end

        def route_for(name, *args)
          Rails.application&.reload_routes_unless_loaded
          super
        end

        def optimize_routes_generation?
          Rails.application&.reload_routes_unless_loaded
          super
        end

        def polymorphic_url(record_or_hash_or_array, options = {})
          Rails.application&.reload_routes_unless_loaded
          super
        end

        def polymorphic_path(record_or_hash_or_array, options = {})
          Rails.application&.reload_routes_unless_loaded
          super
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

      def generate_url_helpers(supports_path)
        super.tap { |mod| mod.singleton_class.prepend(ProxyUrlHelpers) }
      end

      def call(req)
        Rails.application&.reload_routes_unless_loaded
        super
      end

      def draw(&block)
        Rails.application&.reload_routes_unless_loaded
        super
      end

      def recognize_path(path, environment = {})
        Rails.application&.reload_routes_unless_loaded
        super
      end

      def recognize_path_with_request(...)
        Rails.application&.reload_routes_unless_loaded
        super
      end

      def routes
        Rails.application&.reload_routes_unless_loaded
        super
      end

      private
        def method_missing_module
          @method_missing_module ||= Module.new do
            private
              def method_missing(...)
                if Rails.application&.reload_routes_unless_loaded
                  public_send(...)
                else
                  super
                end
              end

              def respond_to_missing?(...)
                if Rails.application&.reload_routes_unless_loaded
                  respond_to?(...)
                else
                  super
                end
              end
          end
        end
    end
  end
end
