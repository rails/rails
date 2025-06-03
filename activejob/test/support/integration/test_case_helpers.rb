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

    def wait_for_jobs_to_finish_for(seconds = 60)
      Timeout.timeout(seconds) do
        while !job_executed do
          sleep 0.25
        end
      end
    rescue Timeout::Error
    end

    def wait_until(timeout: 10)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time < timeout
        return true if yield

        sleep 0.1
      end

      false
    end

    def job_file(id)
      Dummy::Application.root.join("tmp/#{id}")
    end

    def job_executed(id = @id)
      job_file(id).exist?
    end

    def continuable_job_started(id = @id)
      job_file("#{id}.started").exist?
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

    def job_executed_in_timezone(id = @id)
      job_data(id)["timezone"]
    end
end
