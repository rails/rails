require 'generators/erb'

module Erb
  module Generators
    class ControllerGenerator < Base
      argument :actions, :type => :array, :default => [], :banner => "action action"

      def copy_view_files
        base_path = File.join("app/views", class_path, file_name)
        empty_directory base_path

        actions.each do |action|
          @action = action
          @path = filename_with_extensions(File.join(base_path, action))
          template filename_with_extensions(:view), @path
        end
      end
    end
  end
end
