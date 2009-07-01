require 'generators/test_unit'

module TestUnit
  module Generators
    class ScaffoldGenerator < Base
      include Rails::Generators::ScaffoldBase

      class_option :singleton, :type => :boolean, :desc => "Supply to create a singleton controller"
      check_class_collision :suffix => "ControllerTest"

      def create_test_files
        template 'functional_test.rb',
                 File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb")
      end
    end
  end
end
