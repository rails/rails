require 'active_support/concern'
require 'support/integration/jobs_manager'

module TestCaseHelpers
  extend ActiveSupport::Concern

  included do
    self.use_transactional_fixtures = false

    setup do
      clear_jobs
      @id = "AJ-#{SecureRandom.uuid}"
    end

    teardown do
      clear_jobs
    end
  end

  protected

    def jobs_manager
      JobsManager.current_manager
    end

    def clear_jobs
      jobs_manager.clear_jobs
    end

    def adapter_is?(adapter)
      ActiveJob::Base.queue_adapter.name.split("::").last.gsub(/Adapter$/, '').underscore==adapter.to_s
    end

    def wait_for_jobs_to_finish_for(seconds=60)
      begin
        Timeout.timeout(seconds) do
          while !job_executed do
            sleep 0.25
          end
        end
      rescue Timeout::Error
      end
    end

    def job_executed
      Dummy::Application.root.join("tmp/#{@id}").exist?
    end

    def job_output
      File.read Dummy::Application.root.join("tmp/#{@id}")
    end
end
