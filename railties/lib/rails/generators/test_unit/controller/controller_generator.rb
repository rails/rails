require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class ControllerGenerator < Base
      argument :actions, :type => :array, :default => [], :banner => "action action"
      check_class_collision :suffix => "ControllerTest"

      def create_test_files
        template 'functional_test.rb',
                 File.join('test/functional', class_path, "#{file_name}_controller_test.rb")
      end
    end
  end
end
