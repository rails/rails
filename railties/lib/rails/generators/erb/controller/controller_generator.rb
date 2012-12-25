require 'rails/generators/erb'

module Erb # :nodoc:
  module Generators # :nodoc:
    class ControllerGenerator < Base # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"

      def copy_view_files
        base_path = File.join("app/views", class_path, file_name)
        empty_directory base_path

        actions.each do |action|
          @action = action
          @path = File.join(base_path, filename_with_extensions(action))
          template filename_with_extensions(:view), @path
        end
      end
    end
  end
end
