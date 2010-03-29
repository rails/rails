require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class ObserverGenerator < Base
      check_class_collision :suffix => "ObserverTest"

      def create_test_files
        template 'unit_test.rb',  File.join('test/unit', class_path, "#{file_name}_observer_test.rb")
      end
    end
  end
end
