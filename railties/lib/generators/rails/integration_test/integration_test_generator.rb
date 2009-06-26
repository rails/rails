module Rails
  module Generators
    class IntegrationTestGenerator < NamedBase
      def check_class_collisions
        class_collisions class_name, "#{class_name}Test"
      end

      def create_test_files
        template 'integration_test.rb', File.join('test/integration', class_path, "#{file_name}_test.rb")
      end
    end
  end
end
