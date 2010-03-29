require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class IntegrationGenerator < Base
      check_class_collision :suffix => "Test"

      def create_test_files
        template 'integration_test.rb', File.join('test/integration', class_path, "#{file_name}_test.rb")
      end
    end
  end
end
