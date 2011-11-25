require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class SerializerGenerator < Base
      check_class_collision :suffix => "SerializerTest"

      def create_test_files
        template 'unit_test.rb',  File.join('test/unit', class_path, "#{file_name}_serializer_test.rb")
      end
    end
  end
end
