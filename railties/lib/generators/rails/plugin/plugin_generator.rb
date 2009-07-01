module Rails
  module Generators
    class PluginGenerator < NamedBase
      class_option :with_tasks, :type => :boolean, :aliases => "-r", :default => false,
                                :desc => "When supplied creates tasks base files."

      class_option :with_generator, :type => :boolean, :aliases => "-g", :default => false,
                                    :desc => "When supplied creates generator base files."

      check_class_collision

      def create_root
        self.root = File.expand_path("vendor/plugins/#{file_name}", root)
        empty_directory '.' if behavior == :invoke
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

      hook_for :test_framework

      def create_tasks_files
        return unless options[:with_tasks]
        directory 'tasks'
      end

      def create_generator_files
        return unless options[:with_generator]
        directory 'generators'
      end

      # Work around for generator to work on revoke. If we remove the root
      # folder at the beginning, it will raise an error since FileUtils.cd
      # will move to a non-existent folder.
      #
      def remove_on_revoke
        return unless behavior == :revoke
        FileUtils.cd("../../..")
        empty_directory "vendor/plugins/#{file_name}"
      end
    end
  end
end
