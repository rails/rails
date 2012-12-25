require 'rails/generators/resource_helpers'

module Rails
  module Generators
    class ScaffoldControllerGenerator < NamedBase # :nodoc:
      include ResourceHelpers

      check_class_collision suffix: "Controller"

      class_option :orm, banner: "NAME", type: :string, required: true,
                         desc: "ORM to generate the controller for"

      class_option :html, type: :boolean, default: true,
                          desc: "Generate a scaffold with HTML output"

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def handle_skip
        unless options[:html]
          @options = @options.merge(template_engine: false, helper: false)
        end
      end

      def create_controller_files
        template "controller.rb", File.join('app/controllers', class_path, "#{controller_file_name}_controller.rb")
      end

      hook_for :template_engine, :test_framework, as: :scaffold

      # Invoke the helper using the controller name (pluralized)
      hook_for :helper, as: :scaffold do |invoked|
        invoke invoked, [ controller_name ]
      end
    end
  end
end
