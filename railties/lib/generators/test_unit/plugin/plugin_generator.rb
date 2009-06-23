module TestUnit
  module Generators
    class PluginGenerator < Base
      desc <<DESC
Description:
    Create TestUnit files for plugin generator.
DESC

      def create_test_files
        directory 'test'
      end
    end
  end
end
