# frozen_string_literal: true

require "rails/generators/test_unit"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class JobGenerator < Base # :nodoc:
      check_class_collision suffix: "JobTest"

      def create_test_file
        template "unit_test.rb", File.join("test/jobs", class_path, "#{file_name}_job_test.rb")
      end

      private
        def file_name
          @_file_name ||= super.sub(/_job\z/i, "")
        end
    end
  end
end
