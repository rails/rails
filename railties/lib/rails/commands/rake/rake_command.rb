# frozen_string_literal: true

module Rails
  module Command
    class RakeCommand < Base # :nodoc:
      extend Rails::Command::Actions

      namespace "rake"

      class << self
        def printing_commands
          formatted_rake_tasks.map(&:name_with_args)
        end

        def performable_commands_and_options
          rake_tasks.map(&:name_with_args) +
            rake_option_arguments
        end

        def perform(task, args, config)
          require_rake

          Rake.with_application do |rake|
            load "rails/tasks.rb"
            rake.init("rails", [task, *args])
            rake.load_rakefile
            rake.standard_exception_handling { rake.top_level }
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
            @rake_tasks = Rake.application.tasks
          end

          def formatted_rake_tasks
            rake_tasks.select(&:comment)
          end

          def require_rake
            require "rake" # Defer booting Rake until we know it's needed.
          end

          def rake_option_arguments
            options = Rake.application.standard_rake_options.flat_map{ |opt| opt[0..-3] }
            options.map { |opt| opt.split(/( |=)/).first }
          end
      end
    end
  end
end
