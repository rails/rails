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

            previous_routes = klass._routes
            helpers = select_routes_helpers(klass)
            klass.include(helpers)
            prune_helper_methods(klass, previous_routes, helpers._routes, include_path_helpers)
          end

          private
            define_method(:select_routes_helpers) do |klass|
              if namespace = klass.module_parents.detect { |m| m.respond_to?(:railtie_routes_url_helpers) }
                namespace.railtie_routes_url_helpers(include_path_helpers)
              else
                routes.url_helpers(include_path_helpers)
              end
            end

            def prune_helper_methods(klass, previous_routes, desired_routes, include_path_helpers)
              return unless previous_routes
              return if previous_routes.equal?(desired_routes)

              # Remove helpers from an inherited route set so they don't become actions when switching namespaces.
              desired_helpers = desired_routes.named_routes.helper_names
              desired_helpers = desired_helpers.grep(/_url\z/) unless include_path_helpers
              removed_helpers = previous_routes.named_routes.helper_names - desired_helpers
              removed_helpers.each do |helper|
                helper = helper.to_sym
                klass.send(:private, helper) if klass.method_defined?(helper)
              end
            end
        end
      end
    end
  end
end
