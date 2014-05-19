require 'sidekiq'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def queue(job, *args)
          JobWrapper.client_push('class' => JobWrapper, 'queue' => job.queue_name, 'args' => [job, *args])
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
