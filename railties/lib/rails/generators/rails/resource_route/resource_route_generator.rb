# frozen_string_literal: true

module Rails
  module Generators
    class ResourceRouteGenerator < NamedBase # :nodoc:
      # Properly nests namespaces passed into a generator
      #
      #   $ bin/rails generate resource admin/users/products
      #
      # should give you
      #
      #   namespace :admin do
      #     namespace :users do
      #       resources :products
      #     end
      #   end
      def add_resource_route
        return if options[:actions].present?
        route "resources :#{file_name.pluralize}", namespace: regular_class_path
      end
    end
  end
end
