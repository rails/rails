require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class MailerGenerator < Base
      argument :actions, :type => :array, :default => [], :banner => "method method"
      check_class_collision :suffix => "Test"

      def create_test_files
        template "functional_test.rb", File.join('test/functional', class_path, "#{file_name}_test.rb")
      end
    end
  end
end
