require 'active_job/queue_adapter'
require 'active_job/queue_name'
require 'active_job/enqueuing'

module ActiveJob
  class Base
    extend QueueAdapter
    extend QueueName
    extend Enqueuing
  end
end