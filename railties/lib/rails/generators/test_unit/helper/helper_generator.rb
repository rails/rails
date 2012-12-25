require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class HelperGenerator < Base # :nodoc:
      check_class_collision suffix: "HelperTest"

      def create_helper_files
        template 'helper_test.rb', File.join('test/helpers', class_path, "#{file_name}_helper_test.rb")
      end
    end
  end
end
