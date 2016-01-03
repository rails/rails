require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class JobGenerator < Base # :nodoc:
      check_class_collision suffix: 'JobTest'

      def create_test_file
        template 'unit_test.rb.erb', File.join('test/jobs', class_path, "#{file_name}_job_test.rb")
      end
    end
  end
end
