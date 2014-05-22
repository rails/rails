require 'active_job/queue_adapter'
require 'active_job/queue_name'
require 'active_job/enqueuing'
require 'active_job/execution'
require 'active_job/logging'
require 'active_job/callbacks'

module ActiveJob
  class Base
    extend QueueAdapter
    extend QueueName

    include Enqueuing
    include Execution
    include Callbacks
    include Logging

    ActiveSupport.run_load_hooks(:active_job, self)
  end
end
