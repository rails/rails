require 'sucker_punch/testing/inline'
ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::SuckerPunchAdapter
