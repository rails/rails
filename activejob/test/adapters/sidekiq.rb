require "sidekiq/testing/inline"
ActiveJob::Base.queue_adapter = :sidekiq
