# frozen_string_literal: true

require_relative "../../test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class PoroModelGenerator < Base # :nodoc:
      check_class_collision suffix: "Test"

      def create_test_file
        template "unit_test.rb", File.join("test/models", class_path, "#{file_name}_test.rb")
      end
    end
  end
end
