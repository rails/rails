require 'sneakers'
require 'thread'

module ActiveJob
  module QueueAdapters
    class SneakersAdapter
      @monitor = Monitor.new

      class << self
        def enqueue(job)
          @monitor.synchronize do
            JobWrapper.from_queue job.queue_name
            JobWrapper.enqueue ActiveSupport::JSON.encode(job.serialize)
          end
        end

        def enqueue_at(job, timestamp)
          raise NotImplementedError
        end
      end

      class JobWrapper
        include Sneakers::Worker
        from_queue 'default'

        def work(msg)
          job_data = ActiveSupport::JSON.decode(msg)
          Base.execute job_data
          ack!
        end
      end
    end
  end
end
