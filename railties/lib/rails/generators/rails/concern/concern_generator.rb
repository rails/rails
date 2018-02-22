# frozen_string_literal: true

module Rails
  module Generators
    class ConcernGenerator < NamedBase # :nodoc:
      check_class_collision suffix: "Concern"

      def create_concern_files
        template "concern.rb", File.join("app/models/concerns", class_path, "#{file_name}.rb")
      end

      hook_for :test_framework
    end
  end
end
