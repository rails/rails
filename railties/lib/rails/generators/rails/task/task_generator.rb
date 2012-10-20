module Rails
  module Generators
    class TaskGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"
      class_option :task_engine, type: :string, default: 'rake', aliases: '-t'

      def create_task_files
        engine = options[:task_engine].to_sym
        unless [:rake, :thor].include? engine
          raise Error, 'Task engine should be rake or thor'
        end
        template "#{engine}_task.rb", File.join('lib/tasks', "#{file_name}.#{engine}")
      end

    end
  end
end
