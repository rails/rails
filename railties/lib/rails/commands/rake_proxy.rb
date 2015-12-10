require 'rake'

module Rails
  module RakeProxy #:nodoc:

    RAKE_TASKS_HELP_MESSAGE = <<-EOT
In addition to those, you can run the rake tasks as rails commands:

    EOT

    private

      def write_rake_tasks_help_message
        puts RAKE_TASKS_HELP_MESSAGE
      end

      def write_rake_tasks
        width = rake_tasks.map { |t| t.name_with_args.length }.max || 10
        rake_tasks.each do |t|
          printf("#{Rake.application.name} %-#{width}s  # %s\n", t.name_with_args, t.comment)
        end
      end

      def rake_tasks
        return @rake_tasks if defined?(@rake_tasks)

        require_application_and_environment!
        Rake::TaskManager.record_task_metadata = true
        Rake.application.instance_variable_set(:@name, 'rails')
        Rails.application.load_tasks
        @rake_tasks = Rake.application.tasks.select(&:comment)
      end

      def invoke_rake
        Rake.application.standard_exception_handling do
          Rake.application.init('rails')
          Rake.application.load_rakefile
          Rake.application.top_level
        end
      end
  end
end
