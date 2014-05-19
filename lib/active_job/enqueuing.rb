require 'active_job/parameters'

module ActiveJob
  module Enqueuing
    def enqueue(*args)
      queue_adapter.queue self, *Parameters.serialize(args)
    end
  end
end