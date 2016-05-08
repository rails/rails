class RequeueJob < ActiveJob::Base
  def perform
    RequeueJob.perform_later
  end
end

class RequeueWaitJob < ActiveJob::Base
  def perform
    RequeueWaitJob.set(:wait => 1.week).perform_later
  end
end

