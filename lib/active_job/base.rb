require 'active_job/queue_adapter'
require 'active_job/queue_name'
require 'active_job/enqueuing'
require 'active_job/logging'
require 'active_job/log_subscriber'

module ActiveJob
  class Base
    extend QueueAdapter
    extend QueueName
    extend Enqueuing
    extend Logging
  end
end
