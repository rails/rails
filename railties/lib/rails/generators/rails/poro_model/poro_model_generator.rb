# frozen_string_literal: true

require_relative "../../model_helpers"

module Rails
  module Generators
    class PoroModelGenerator < NamedBase # :nodoc:
      include Rails::Generators::ModelHelpers

      def create_model_file
        template "model.rb", File.join("app/models", class_path, "#{file_name}.rb")
      end

      hook_for :test_framework
    end
  end
end
