class QueueAdapterJob < ActiveJob::Base
  self.queue_adapter = :inline
end
