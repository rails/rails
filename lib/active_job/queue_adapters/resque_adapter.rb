require 'resque'

module ActiveJob
  module QueueAdapters
    class ResqueAdapter
      class << self
        def queue(job, *args)
          Resque.enqueue(job, *args)
        end
      end
    end
  end
end