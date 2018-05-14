# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class IntegrationGenerator < Base # :nodoc:
      check_class_collision suffix: "Test"

      def create_test_files
        template "integration_test.rb", File.join("test/integration", class_path, "#{file_name}_test.rb")
      end
    end
  end
end
