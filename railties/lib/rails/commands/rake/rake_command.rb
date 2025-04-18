# frozen_string_literal: true

module Rails
  module Command
    class RakeCommand < Base # :nodoc:
      extend Rails::Command::Actions

      namespace "rake"

      class << self
        def printing_commands
          rake_tasks.filter_map do |task|
            if task.comment && task.locations.any?(non_app_file_pattern)
              [task.name_with_args, task.comment]
            end
          end
        end

        def perform(task, args, config)
          with_rake(task, *args) do |rake|
            if unrecognized_task = (rake.top_level_tasks - ["default"]).find { |task| !rake.lookup(task[/[^\[]+/]) }
              @rake_tasks = rake.tasks
              raise UnrecognizedCommandError.new(unrecognized_task)
            end

            rake.options.suppress_backtrace_pattern = non_app_file_pattern
            rake.standard_exception_handling { rake.top_level }
          end
        end

        private
          def non_app_file_pattern
            /\A(?!#{Regexp.quote Rails::Command.root.to_s})/
          end

          def with_rake(*args, &block)
            require "rake"
            Rake::TaskManager.record_task_metadata = true

            result = nil
            Rake.with_application do |rake|
              rake.init(bin, args) unless args.empty?
              rake.load_rakefile
              result = block.call(rake)
            end
            result
          end

          def rake_tasks
            @rake_tasks ||= with_rake(&:tasks)
          end
      end
    end
  end
end
