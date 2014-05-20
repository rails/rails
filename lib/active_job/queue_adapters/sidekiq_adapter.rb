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
            'at'    => timestamp,
            'retry' => true
        end
      end

      class JobWrapper
        include Sidekiq::Worker

        def perform(job_name, *args)
          job_name.constantize.new.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end
