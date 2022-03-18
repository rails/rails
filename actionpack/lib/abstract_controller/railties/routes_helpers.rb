# frozen_string_literal: true

require "active_support/core_ext/module/introspection"

module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)

            namespace = klass.module_parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
            actual_routes = namespace ? namespace.railtie_routes_url_helpers._routes : routes

            if namespace
              klass.include(namespace.railtie_routes_url_helpers(include_path_helpers))
            else
              klass.include(routes.url_helpers(include_path_helpers))
            end

            # In the case that we have ex.
            #   class A::Foo < ApplicationController
            #   class Bar < A::Foo
            # We will need to redefine _routes because it will not be correct
            # via inheritance.
            unless klass._routes.equal?(actual_routes)
              klass.redefine_singleton_method(:_routes) { actual_routes }
              klass.include(Module.new do
                define_method(:_routes) { @_routes || actual_routes }
              end)
            end
          end
        end
      end
    end
  end
end
