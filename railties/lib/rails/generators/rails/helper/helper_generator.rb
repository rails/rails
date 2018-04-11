# frozen_string_literal: true

module Rails
  module Generators
    class HelperGenerator < NamedBase # :nodoc:
      check_class_collision suffix: "Helper"

      def create_helper_files
        primary_template "helper.rb", File.join("app/helpers", class_path, "#{file_name}_helper.rb")
      end

      hook_for :test_framework
    end
  end
end
