# frozen_string_literal: true

module Rails
  module Generators
    class TaskGenerator < NamedBase # :nodoc:
      argument :actions, type: :array, default: [], banner: "action action"

      def create_task_files
        primary_template "task.rb", File.join("lib/tasks", "#{file_name}.rake")
      end
    end
  end
end
