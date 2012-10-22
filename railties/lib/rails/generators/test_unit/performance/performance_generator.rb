require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class PerformanceGenerator < Base # :nodoc:
      check_class_collision suffix: "Test"

      def create_test_files
        template 'performance_test.rb', File.join('test/performance', class_path, "#{file_name}_test.rb")
      end
    end
  end
end
