# frozen_string_literal: true

require 'delayed_job'
require 'delayed_job_active_record'

module DelayedJobJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :delayed_job
  end
  def clear_jobs
    Delayed::Job.delete_all
  end

  def start_workers
    @worker = Delayed::Worker.new(quiet: true, sleep_delay: 0.5, queues: %w(integration_tests))
    @thread = Thread.new { @worker.start }
  end

  def stop_workers
    @worker.stop
    @thread.join
  end
end
