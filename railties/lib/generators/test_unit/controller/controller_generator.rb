require 'generators/test_unit'

module TestUnit
  module Generators
    class ControllerGenerator < Base
      check_class_collision :suffix => "ControllerTest"

      def create_test_files
        template 'functional_test.rb',
                 File.join('test/functional', class_path, "#{file_name}_controller_test.rb")
      end
    end
  end
end
