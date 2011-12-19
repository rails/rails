require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class ModuleGenerator < Base
      argument :actions, :type => :array, :default => [], :banner => "action action"
      check_class_collision :suffix => "Test"

      def create_test_file
        template 'unit_test.rb', File.join('test/unit', "#{file_name}_test.rb")
      end
      
    end
  end
end
