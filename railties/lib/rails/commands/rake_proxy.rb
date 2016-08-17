require "active_support"

module Rails
  module RakeProxy #:nodoc:
    private
      def run_rake_task(command)
        require_rake

        ARGV.unshift(command) # Prepend the command, so Rake knows how to run it.

        Rake.application.standard_exception_handling do
          Rake.application.init("rails")
          Rake.application.load_rakefile
          Rake.application.top_level
        end
      end

      def rake_tasks
        require_rake

        return @rake_tasks if defined?(@rake_tasks)

        ActiveSupport::Deprecation.silence do
          require_application_and_environment!
        end

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
