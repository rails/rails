require 'active_job/queue_adapter'
require 'active_job/queue_name'
require 'active_job/enqueuing'
require 'active_job/performing'
require 'active_job/logging'

module ActiveJob
  class Base
    extend QueueAdapter
    extend QueueName
    extend Enqueuing
    include Performing
    extend Logging

    ActiveSupport.run_load_hooks(:active_job, self)
  end
end
