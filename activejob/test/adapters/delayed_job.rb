# frozen_string_literal: true

ActiveJob::Base.queue_adapter = :delayed_job

$LOAD_PATH << File.expand_path("../support/delayed_job", __dir__)

Delayed::Worker.delay_jobs = false
Delayed::Worker.backend    = :test
