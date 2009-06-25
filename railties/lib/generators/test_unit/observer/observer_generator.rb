module TestUnit
  module Generators
    class ObserverGenerator < Base
      desc <<DESC
Description:
    Create TestUnit files for observer generator.
DESC

      def create_test_files
        template 'unit_test.rb',  File.join('test', 'unit', class_path, "#{file_name}_observer_test.rb")
      end
    end
  end
end
