# frozen_string_literal: true

module Rails
  module Generators
    class ControllerGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: 'action action'
      class_option :skip_routes, type: :boolean, desc: "Don't add routes to config/routes.rb."
      class_option :helper, type: :boolean
      class_option :assets, type: :boolean

      check_class_collision suffix: 'Controller'

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{file_name}_controller.rb")
      end

      def add_routes
        return if options[:skip_routes]
        return if actions.empty?
        routing_code = actions.map { |action| "get '#{file_name}/#{action}'" }.join("\n")
        route routing_code, namespace: regular_class_path
      end

      hook_for :template_engine, :test_framework, :helper, :assets do |generator|
        invoke generator, [ remove_possible_suffix(name), actions ]
      end

      private
        def file_name
          @_file_name ||= remove_possible_suffix(super)
        end

        def remove_possible_suffix(name)
          name.sub(/_?controller$/i, '')
        end
    end
  end
end
