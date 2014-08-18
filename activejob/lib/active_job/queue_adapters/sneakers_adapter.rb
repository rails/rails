require 'sneakers'
require 'thread'

module ActiveJob
  module QueueAdapters
    class SneakersAdapter
      @monitor = Monitor.new

      class << self
        def enqueue(job, *args)
          @monitor.synchronize do
            JobWrapper.from_queue job.queue_name
            JobWrapper.enqueue ActiveSupport::JSON.encode([ job.name, *args ])
          end
        end

        def enqueue_at(job, timestamp, *args)
          raise NotImplementedError
        end
      end

      class JobWrapper
        include Sneakers::Worker
        from_queue 'active_jobs_default'

        def work(msg)
          job_name, *args = ActiveSupport::JSON.decode(msg)
          job_name.constantize.new.execute(*args)
          ack!
        end
      end
    end
  end
end
