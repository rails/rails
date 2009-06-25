module TestUnit
  module Generators
    class PluginGenerator < Base
      def create_test_files
        directory 'test'
      end
    end
  end
end
