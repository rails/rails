require 'generators/rails/generator/generator_generator'

module Rails
  module Generators
    class PluginGenerator < NamedBase
      class_option :tasks, :desc => "When supplied creates tasks base files."

      check_class_collision

      def create_root_files
        directory '.', plugin_dir, :recursive => false
      end

      def create_lib_files
        directory 'lib', plugin_dir('lib'), :recursive => false
      end

      def create_tasks_files
        return unless options[:tasks]
        directory 'tasks', plugin_dir('tasks')
      end

      hook_for :generator do |instance, generator|
        instance.inside instance.send(:plugin_dir), :verbose => true do
          instance.invoke generator, [ instance.name ], :namespace => false
        end
      end

      hook_for :test_framework do |instance, test_framework|
        instance.inside instance.send(:plugin_dir), :verbose => true do
          instance.invoke test_framework
        end
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
