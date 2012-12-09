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
          return if attributes.empty?

          hash_values = []
          attributes.each do |a|
            hash_values << hash_value(a.reference? ? "#{a.name}_id" : a.name)
            hash_values << hash_value("#{a.name}_type") if a.polymorphic?
          end

          hash_values.sort.join(', ')
        end

        def hash_value(name)
          "#{name}: @#{singular_table_name}.#{name}"
        end
    end
  end
end
