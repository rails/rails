require 'sidekiq'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def queue(job, *args)
          Sidekiq::Client.push \
            'class' => JobWrapper,
            'queue' => job.queue_name,
            'args'  => [ job, *args ],
            'retry' => true
        end

        def queue_at(job, timestamp, *args)
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
          job_name.constantize.new.perform_with_deserialization *args
        end
      end
    end
  end
end
