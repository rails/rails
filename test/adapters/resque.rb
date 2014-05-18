ActiveJob::Base.queue_adapter = ActiveJob::QueueAdapters::ResqueAdapter
Resque.inline = true
