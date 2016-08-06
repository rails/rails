require "rake"
require "active_support"

module Rails
  module RakeProxy #:nodoc:
    private
      def run_rake_task(command)
        ARGV.unshift(command) # Prepend the command, so Rake knows how to run it.

        Rake.application.standard_exception_handling do
          Rake.application.init("rails")
          Rake.application.load_rakefile
          Rake.application.top_level
        end
      end

      def rake_tasks
        return @rake_tasks if defined?(@rake_tasks)

        ActiveSupport::Deprecation.silence do
          require_application_and_environment!
        end

        Rake::TaskManager.record_task_metadata = true
        Rake.application.instance_variable_set(:@name, "rails")
        Rails.application.load_tasks
        @rake_tasks = Rake.application.tasks.select(&:comment)
      end

      def formatted_rake_tasks
        rake_tasks.map { |t| [ t.name_with_args, t.comment ] }
      end
  end
end
