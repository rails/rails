require 'concurrent'
require 'active_job/async_job'

ActiveJob::Base.queue_adapter = :async
ActiveJob::AsyncJob.perform_immediately!
