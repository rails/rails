require 'sneakers'
require 'thread'

module ActiveJob
  module QueueAdapters
    class SneakersAdapter
      @mutex = Mutex.new
        
      class << self
        def queue(job, *args)
          @mutex.synchronize do
            JobWrapper.from_queue job.queue_name
            JobWrapper.enqueue [ job, *args ]
          end
        end
      end

      class JobWrapper
        include Sneakers::Worker

        def work(job, *args)
          job.new.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end
