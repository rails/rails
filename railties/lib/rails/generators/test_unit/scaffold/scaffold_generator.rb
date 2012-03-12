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

      def accessible_attributes
        attributes.reject(&:reference?).map {|a| "\"#{a.name}\"" }.sort.join(', ')
      end
    end
  end
end
