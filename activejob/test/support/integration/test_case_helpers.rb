# frozen_string_literal: true

require "support/integration/jobs_manager"

module TestCaseHelpers
  extend ActiveSupport::Concern

  included do
    self.use_transactional_tests = false

    setup do
      clear_jobs
      @id = "AJ-#{SecureRandom.uuid}"
    end

    teardown do
      clear_jobs
    end
  end

  private

    def jobs_manager
      JobsManager.current_manager
    end

    def clear_jobs
      jobs_manager.clear_jobs
    end

    def adapter_is?(*adapter_class_symbols)
      adapter_class_symbols.map(&:to_s).include? ActiveJob::Base.queue_adapter_name
    end

    def wait_for_jobs_to_finish_for(seconds = 60)
      begin
        Timeout.timeout(seconds) do
          while !job_executed do
            sleep 0.25
          end
        end
      rescue Timeout::Error
      end
    end

    def job_file(id)
      Dummy::Application.root.join("tmp/#{id}")
    end

    def job_executed(id = @id)
      job_file(id).exist?
    end

    def job_data(id)
      Marshal.load(File.binread(job_file(id)))
    end

    def job_executed_at(id = @id)
      job_data(id)["executed_at"]
    end

    def job_executed_in_locale(id = @id)
      job_data(id)["locale"]
    end
end
