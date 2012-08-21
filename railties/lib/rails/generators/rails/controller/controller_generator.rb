module Rails
  module Generators
    class ControllerGenerator < NamedBase
      argument :actions, :type => :array, :default => [], :banner => "action action"
      check_class_collision :suffix => "Controller"

      def create_controller_files
        template 'controller.rb', File.join('app/controllers', class_path, "#{file_name}_controller.rb")
      end

      def add_routes
        route_path = (class_path | [file_name]).join '/'
        actions.reverse.each do |action|
          route %{get "#{route_path}/#{action}"}
        end
      end

      hook_for :template_engine, :test_framework, :helper, :assets
    end
  end
end
