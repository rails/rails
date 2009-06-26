module Rails
  module Generators
    class ControllerGenerator < NamedBase
      argument :actions, :type => :array, :default => [], :banner => "action action"
      check_class_collision :suffix => "Controller"

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{file_name}_controller.rb")
      end

      invoke_for :template_engine, :test_framework
      invoke_if :helper, :aliases => "-v"
    end
  end
end
