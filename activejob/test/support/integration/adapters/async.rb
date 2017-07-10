# frozen_string_literal: true

module AsyncJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :async
    ActiveJob::Base.queue_adapter.immediate = false
  end

  def clear_jobs
    ActiveJob::Base.queue_adapter.shutdown
  end
end
