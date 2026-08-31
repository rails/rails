# frozen_string_literal: true

# :markup: markdown

require "action_dispatch/routing/route_set"

# :enddoc:

module Rails
  class Engine
    class LazyRouteSet < ActionDispatch::Routing::RouteSet
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
      end

      # Mounted helpers are only defined when `mount` runs during the route
      # draw. _path/_url names are left to method_missing_module, which owns
      # them and relies on reload_routes_unless_loaded returning true only to
      # the caller that performed the load.
      module MountedHelpers
        extend ActiveSupport::Concern

        include ActionDispatch::Routing::RouteSet::MountedHelpers

        private
          def method_missing(method_name, ...)
            if method_name.end_with?("_path", "_url")
              super
            else
              Rails.application&.reload_routes_unless_loaded
              if ActionDispatch::Routing::RouteSet::MountedHelpers.method_defined?(method_name)
                public_send(method_name, ...)
              else
                super
              end
            end
          end

          def respond_to_missing?(method_name, include_private = false)
            if method_name.end_with?("_path", "_url")
              super
            else
              Rails.application&.reload_routes_unless_loaded
              ActionDispatch::Routing::RouteSet::MountedHelpers.method_defined?(method_name) || super
            end
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

      def polymorphic_mappings
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

      def mounted_helpers
        MountedHelpers
      end

      def define_mounted_helper(name, script_namer = nil)
        super

        return if MountedHelpers.method_defined?(name)

        shared = ActionDispatch::Routing::RouteSet::MountedHelpers
        MountedHelpers.define_method("_#{name}", shared.instance_method("_#{name}"))
        MountedHelpers.define_method(name, shared.instance_method(name))
      end

      private
        def method_missing_module
          @method_missing_module ||= Module.new do
            private
              # NamedRouteCollection#define_url_helper only defines "#{name}_path"
              # and "#{name}_url" in these modules, so other suffixes can never be
              # lazy route helpers. Without this guard, including url_helpers into
              # Object makes every respond_to?(:to_ary) (and similar) re-enter
              # reload_routes_unless_loaded and thrash while routes are drawing.
              def method_missing(method_name, ...)
                if method_name.end_with?("_path", "_url") && Rails.application&.reload_routes_unless_loaded
                  public_send(method_name, ...)
                else
                  super
                end
              end

              def respond_to_missing?(method_name, include_private = false)
                if method_name.end_with?("_path", "_url") && Rails.application&.reload_routes_unless_loaded
                  respond_to?(method_name, include_private)
                else
                  super
                end
              end
          end
        end
    end
  end
end
