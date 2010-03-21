require 'generators/erb'

module Erb
  module Generators
    class ControllerGenerator < Base
      argument :actions, :type => :array, :default => [], :banner => "action action"

      def copy_view_files
        base_path = File.join("app/views", class_path, file_name)
        empty_directory base_path

        actions.each do |action|
          @action, @path = action, File.join(base_path, action)
          template filename_with_extensions(:view), filename_with_extensions(@path)
        end
      end
    end
  end
end
