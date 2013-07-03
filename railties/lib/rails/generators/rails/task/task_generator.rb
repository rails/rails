module Rails
  module Generators
    class TaskGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"

      def create_task_files
        destination = File.join('lib/tasks', "#{file_name}.rake")
        template 'task.rb', destination
        open_file_in_editor(destination) if options["editor"].present?
      end

    end
  end
end
