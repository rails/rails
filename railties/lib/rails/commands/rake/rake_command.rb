# frozen_string_literal: true

module Rails
  module Command
    class RakeCommand < Base # :nodoc:
      extend Rails::Command::Actions

      namespace "rake"

      class << self
        def printing_commands
          formatted_rake_tasks
        end

        def perform(task, args, config)
          require_rake

          Rake.with_application do |rake|
            rake.init("bin/rails", [task, *args])
            rake.load_rakefile
            if unrecognized_task = rake.top_level_tasks.find { |task| !rake.lookup(task[/[^\[]+/]) }
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

          def rake_tasks
            require_rake

            return @rake_tasks if defined?(@rake_tasks)

            Rake::TaskManager.record_task_metadata = true
            Rake.application.instance_variable_set(:@name, "rails")
            Rake.application.load_rakefile
            @rake_tasks = Rake.application.tasks.select do |task|
              task.comment && task.locations.any?(non_app_file_pattern)
            end
          end

          def formatted_rake_tasks
            rake_tasks.map { |t| [ t.name_with_args, t.comment ] }
          end

          def require_rake
            require "rake" # Defer booting Rake until we know it's needed.
          end
      end
    end
  end
end
