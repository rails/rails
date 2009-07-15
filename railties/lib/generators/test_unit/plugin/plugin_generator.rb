require 'generators/test_unit'

module TestUnit
  module Generators
    class PluginGenerator < Base
      check_class_collision :suffix => "Test"

      def create_test_files
        directory '.', 'test'
      end
    end
  end
end
