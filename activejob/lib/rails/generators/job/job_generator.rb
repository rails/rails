# frozen_string_literal: true

require "rails/generators/named_base"

module Rails # :nodoc:
  module Generators # :nodoc:
    class JobGenerator < Rails::Generators::NamedBase # :nodoc:
      desc "This generator creates an active job file at app/jobs"

      class_option :queue, type: :string, default: "default", desc: "The queue name for the generated job"

      check_class_collision suffix: "Job"

      hook_for :test_framework

      def self.default_generator_root
        __dir__
      end

      def create_job_file
        template "job.rb", File.join("app/jobs", class_path, "#{file_name}_job.rb")

        in_root do
          if behavior == :invoke && !File.exist?(application_job_file_name)
            template "application_job.rb", application_job_file_name
          end
        end
      end

      private
        def file_name
          @_file_name ||= super.sub(/_job\z/i, "")
        end

        def application_job_file_name
          @application_job_file_name ||= if mountable_engine?
            "app/jobs/#{namespaced_path}/application_job.rb"
          else
            "app/jobs/application_job.rb"
          end
        end
    end
  end
end
