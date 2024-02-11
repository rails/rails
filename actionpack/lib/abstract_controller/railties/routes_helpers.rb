# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/module/introspection"

module AbstractController
  module Railties
    module RoutesHelpers
      def self.with(routes, include_path_helpers = true)
        Module.new do
          define_method(:inherited) do |klass|
            super(klass)

            if namespace = klass.module_parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
              klass.include(namespace.railtie_routes_url_helpers(include_path_helpers))
            else
              klass.include(routes.url_helpers(include_path_helpers))
            end
          end
        end
      end
    end
  end
end
