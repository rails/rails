module Rails
  module Generators
    class ModuleGenerator < NamedBase
      argument :actions, :type => :array, :default => [], :banner => "action action"
      check_class_collision

      def create_controller_files
        template 'module.rb', File.join('lib', "#{file_name}.rb")
      end

      hook_for :test_framework
    end
  end
end
