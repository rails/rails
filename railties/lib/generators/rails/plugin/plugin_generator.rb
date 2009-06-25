module Rails
  module Generators
    class PluginGenerator < NamedBase
      class_option :with_tasks, :type => :boolean, :aliases => "-r", :default => false,
                                :desc => "When supplied creates tasks base files."

      class_option :with_generator, :type => :boolean, :aliases => "-g", :default => false,
                                    :desc => "When supplied creates generator base files."

      # TODO Check class collision

      def create_root
        self.root = File.expand_path("vendor/plugins/#{file_name}", root)
        empty_directory '.'
        FileUtils.cd(root)
      end

      def create_root_files
        %w(README MIT-LICENSE Rakefile init.rb install.rb uninstall.rb).each do |file|
          template file
        end
      end

      def create_lib_files
        directory 'lib'
      end

      add_and_invoke_test_framework_option!

      def create_tasks_files
        return unless options[:with_tasks]
        directory 'tasks'
      end

      def create_generator_files
        return unless options[:with_generator]
        directory 'generators'
      end
    end
  end
end
