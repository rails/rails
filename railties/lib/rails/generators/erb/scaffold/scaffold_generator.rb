# frozen_string_literal: true

require "rails/generators/erb"
require "rails/generators/resource_helpers"

module Erb # :nodoc:
  module Generators # :nodoc:
    class ScaffoldGenerator < Base # :nodoc:
      include Rails::Generators::ResourceHelpers

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def create_root_directory
        empty_directory base_path
      end

      def create_view_files
        available_views.each do |view|
          formats.each do |format|
            filename = filename_with_extensions(view, format)
            template filename, File.join(base_path, filename)
          end
        end
      end

      private
        def base_path
          File.join("app/views", controller_file_path)
        end

        def available_views
          %w(index edit show new _form)
        end
    end
  end
end
