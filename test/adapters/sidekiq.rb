require 'sidekiq/testing/inline'
ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::SidekiqAdapter
