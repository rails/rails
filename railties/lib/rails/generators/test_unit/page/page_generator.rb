# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class PageGenerator < Base # :nodoc:
      class_option :root, type: :boolean

      check_class_collision suffix: "ControllerTest"

      def create_test_files
        template "functional_test.rb",
                 File.join("test/controllers", class_path, "#{file_name}_controller_test.rb")
      end
    end
  end
end
