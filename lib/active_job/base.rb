require 'active_job/queue_adapter'
require 'active_job/queue_name'

module ActiveJob
  class Base
    extend QueueAdapter
    extend QueueName

    def self.enqueue(*args)
      queue_adapter.queue self, *args
    end
  end
end