# frozen_string_literal: true

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
