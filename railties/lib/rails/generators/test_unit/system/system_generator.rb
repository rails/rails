require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class SystemGenerator < Base # :nodoc:
      check_class_collision suffix: "Test"

      def create_test_files
        template "system_test.rb", File.join("test/system", class_path, "#{file_name.pluralize}_test.rb")
      end
    end
  end
end
