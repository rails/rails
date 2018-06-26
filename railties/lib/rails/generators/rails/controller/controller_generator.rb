# frozen_string_literal: true

module Rails
  module Generators
    class ControllerGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"
      class_option :skip_routes, type: :boolean, desc: "Don't add routes to config/routes.rb."
      class_option :helper, type: :boolean
      class_option :assets, type: :boolean

      check_class_collision suffix: "Controller"

      def create_controller_files
        template "controller.rb", File.join("app/controllers", class_path, "#{file_name}_controller.rb")
      end

      def add_routes
        return if options[:skip_routes]
        return if actions.empty?
        route generate_routing_code
      end

      hook_for :template_engine, :test_framework, :helper, :assets do |generator|
        invoke generator, [ remove_possible_suffix(name), actions ]
      end

      private

        def file_name
          @_file_name ||= remove_possible_suffix(super)
        end

        def remove_possible_suffix(name)
          name.sub(/_?controller$/i, "")
        end

        # This method creates nested route entry for namespaced resources.
        # For eg. bin/rails g controller foo/bar/baz index show
        # Will generate -
        # namespace :foo do
        #   namespace :bar do
        #     get 'baz/index'
        #     get 'baz/show'
        #   end
        # end
        def generate_routing_code
          depth = 0
          lines = []

          # Create 'namespace' ladder
          # namespace :foo do
          #   namespace :bar do
          regular_class_path.each do |ns|
            lines << indent("namespace :#{ns} do\n", depth * 2)
            depth += 1
          end

          # Create route
          #     get 'baz/index'
          #     get 'baz/show'
          actions.each do |action|
            lines << indent(%{get '#{file_name}/#{action}'\n}, depth * 2)
          end

          # Create `end` ladder
          #   end
          # end
          until depth.zero?
            depth -= 1
            lines << indent("end\n", depth * 2)
          end

          lines.join
        end
    end
  end
end
