require 'rails/generators/test_unit'
require 'rails/generators/resource_helpers'

module TestUnit
  module Generators
    class ScaffoldGenerator < Base
      include Rails::Generators::ResourceHelpers

      check_class_collision :suffix => "ControllerTest"

      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"

      def create_test_files
        template 'functional_test.rb',
                 File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb")
      end

      private

        def resource_attributes
          key_value singular_table_name, "{ #{attributes_hash} }"
        end

        def attributes_hash
          return if accessible_attributes.empty?

          accessible_attributes.map do |a|
            name = a.name
            key_value name, "@#{singular_table_name}.#{name}"
          end.sort.join(', ')
        end

        def accessible_attributes
          attributes.reject(&:reference?)
        end
    end
  end
end
