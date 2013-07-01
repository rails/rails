require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class ValidatorGenerator < Base # :nodoc:
      check_class_collision suffix: "Test"

      def create_test_file
        template 'validator_test.rb', File.join('test/validators', class_path, "#{file_name}_validator_test.rb")
      end
    end
  end
end
