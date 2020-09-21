# frozen_string_literal: true

module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)

            namespace = klass.module_parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
            previous_namespace = klass._route_namespace if klass.respond_to?(:_route_namespace)
            fresh_module = namespace != previous_namespace

            if namespace
              klass.include(namespace.railtie_routes_url_helpers(include_path_helpers, fresh_module))
            else
              klass.include(routes.url_helpers(include_path_helpers, fresh_module))
            end

            if fresh_module
              klass.define_singleton_method(:_route_namespace) { namespace }
            end
          end
        end
      end
    end
  end
end
