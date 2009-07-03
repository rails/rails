module Rails
  module Generators
    class PluginGenerator < NamedBase
      class_option :tasks, :type => :boolean, :aliases => "-t", :default => false,
                           :desc => "When supplied creates tasks base files."

      class_option :generator, :type => :boolean, :aliases => "-g", :default => false,
                               :desc => "When supplied creates generator base files."

      check_class_collision

      def create_root_files
        directory '.', plugin_dir, false # non-recursive
      end

      def create_lib_files
        directory 'lib', plugin_dir('lib'), false # non-recursive
      end

      hook_for :test_framework

      def create_tasks_files
        return unless options[:tasks]
        directory 'tasks', plugin_dir('tasks')
      end

      def create_generator_files
        return unless options[:generator]
        directory 'generators', plugin_dir('generators')
      end

      protected

        def plugin_dir(join=nil)
          if join
            File.join(plugin_dir, join)
          else
            "vendor/plugins/#{file_name}"
          end
        end

    end
  end
end
