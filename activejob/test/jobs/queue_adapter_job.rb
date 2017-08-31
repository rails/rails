# frozen_string_literal: true

class QueueAdapterJob < ActiveJob::Base
  self.queue_adapter = :inline
end
