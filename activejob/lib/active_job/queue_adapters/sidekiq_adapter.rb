require 'sidekiq'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def enqueue(job, *args)
          #Sidekiq::Client does not support symbols as keys
          Sidekiq::Client.push \
            'class' => JobWrapper,
            'queue' => job.queue_name,
            'args'  => [ job, *args ],
            'retry' => true
        end

        def enqueue_at(job, timestamp, *args)
          Sidekiq::Client.push \
            'class' => JobWrapper,
            'queue' => job.queue_name,
            'args'  => [ job, *args ],
            'retry' => true,
            'at'    => timestamp
        end
      end

      class JobWrapper
        include Sidekiq::Worker

        def perform(job_name, *args)
          job_name.constantize.new.execute(*args)
        end
      end
    end
  end
end
