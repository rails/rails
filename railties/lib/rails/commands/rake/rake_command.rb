# frozen_string_literal: true

module Rails
  module Command
    class RakeCommand < Base # :nodoc:
      extend Rails::Command::Actions

      namespace "rake"

      class << self
        def printing_commands
          formatted_rake_tasks.map(&:first)
        end

        def perform(task, args, config)
          require_rake

          test_task = rake_tasks.find { |t| t.name == task } if task.start_with?("test:")
          
          Rake.with_application do |rake|
            rake_init_args = test_task ? [] : [task, *args]
            rake.init("rails", rake_init_args)
            rake.load_rakefile
            if Rails.respond_to?(:root)
              rake.options.suppress_backtrace_pattern = /\A(?!#{Regexp.quote(Rails.root.to_s)})/
            end

            rake.standard_exception_handling do
              test_task ? test_task.invoke(args) : rake.top_level
            end
          end
        end

        private
          def rake_tasks
            require_rake

            return @rake_tasks if defined?(@rake_tasks)

            require_application!

            Rake::TaskManager.record_task_metadata = true
            Rake.application.instance_variable_set(:@name, "rails")
            load_tasks
            @rake_tasks = Rake.application.tasks.select(&:comment)
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
