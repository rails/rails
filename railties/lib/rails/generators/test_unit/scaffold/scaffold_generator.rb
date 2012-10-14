require 'rails/generators/test_unit'
require 'rails/generators/resource_helpers'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class ScaffoldGenerator < Base # :nodoc:
      include Rails::Generators::ResourceHelpers

      check_class_collision suffix: "ControllerTest"

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def create_test_files
        template "functional_test.rb",
                 File.join("test/controllers", controller_class_path, "#{controller_file_name}_controller_test.rb")
      end

      private

        def attributes_hash
          return if accessible_attributes.empty?

          accessible_attributes.map do |a|
            name = a.name
            "#{name}: @#{singular_table_name}.#{name}"
          end.sort.join(', ')
        end

        def accessible_attributes
          attributes.reject(&:reference?)
        end
    end
  end
end
