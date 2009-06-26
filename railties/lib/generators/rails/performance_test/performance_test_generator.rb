module Rails
  module Generators
    class PerformanceTestGenerator < NamedBase
      def check_class_collisions
        class_collisions "#{class_name}Test"
      end

      def create_test_files
        template 'performance_test.rb', File.join('test/performance', class_path, "#{file_name}_test.rb")
      end
    end  end
end
