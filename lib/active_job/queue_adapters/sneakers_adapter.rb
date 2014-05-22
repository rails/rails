require 'sneakers'
require 'thread'

module ActiveJob
  module QueueAdapters
    class SneakersAdapter
      @mutex = Mutex.new
        
      class << self
        def enqueue(job, *args)
          @mutex.synchronize do
            JobWrapper.from_queue job.queue_name
            JobWrapper.enqueue [ job, *args ]
          end
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper
        include Sneakers::Worker

        def work(job, *args)
          job.new.perform_with_hooks *args
        end
      end
    end
  end
end
