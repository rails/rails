module Rails
  module Generators
    class HelperGenerator < NamedBase
      def check_class_collisions
        class_collisions "#{class_name}Helper"
      end

      def create_helper_files
        template 'helper.rb', File.join('app/helpers', class_path, "#{file_name}_helper.rb")
      end

      invoke_for :test_framework
    end
  end
end
