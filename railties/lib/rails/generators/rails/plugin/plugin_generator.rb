
require 'rails/generators/rails/generator/generator_generator'

module Rails
  module Generators
    class PluginGenerator < NamedBase
      class_option :tasks, :desc => "When supplied creates tasks base files."

      def show_deprecation
        return unless behavior == :invoke
        message = "Plugin generator is deprecated, please use 'rails plugin new' command to generate plugin structure."
        ActiveSupport::Deprecation.warn message
      end

      check_class_collision

      def create_root_files
        directory '.', plugin_dir, :recursive => false
      end

      def create_lib_files
        directory 'lib', plugin_dir('lib'), :recursive => false
      end

      def create_tasks_files
        return unless options[:tasks]
        directory 'lib/tasks', plugin_dir('lib/tasks')
      end

      hook_for :generator do |generator|
        inside plugin_dir, :verbose => true do
          invoke generator, [ name ], :namespace => false
        end
      end

      hook_for :test_framework do |test_framework|
        inside plugin_dir, :verbose => true do
          invoke test_framework
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
