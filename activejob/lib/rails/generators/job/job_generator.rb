require 'rails/generators/named_base'

module Rails
  module Generators # :nodoc:
    class JobGenerator < Rails::Generators::NamedBase # :nodoc:
      desc 'This generator creates an active job file at app/jobs'

      class_option :queue, type: :string, default: 'default', desc: 'The queue name for the generated job'

      check_class_collision suffix: 'Job'

      hook_for :test_framework

      def self.default_generator_root
        File.dirname(__FILE__)
      end

      def create_job_file
        template 'job.rb', File.join('app/jobs', class_path, "#{file_name}_job.rb")
      end

    end
  end
end
