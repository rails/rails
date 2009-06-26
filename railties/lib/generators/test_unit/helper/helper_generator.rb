module TestUnit
  module Generators
    class HelperGenerator < Base
      def check_class_collisions
        class_collisions "#{class_name}HelperTest"
      end

      def create_helper_files
        template 'helper_test.rb', File.join('test/unit/helpers', class_path, "#{file_name}_helper_test.rb")
      end
    end
  end
end
