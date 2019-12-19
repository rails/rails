# frozen_string_literal: true

module SuckerPunchJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :sucker_punch
    SuckerPunch.logger = nil
  end
end
