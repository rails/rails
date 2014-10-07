module SuckerPunchJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :sucker_punch
  end
end
