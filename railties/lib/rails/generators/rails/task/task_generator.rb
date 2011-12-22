module Rails
  module Generators
    class TaskGenerator < NamedBase
      argument :actions, :type => :array, :default => [], :banner => "action action"

      def create_task_files
        template 'task.rb', File.join('lib/tasks', "#{file_name}.rake")
      end

    end
  end
end
