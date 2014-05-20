require 'sidekiq'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def queue(job, *args)
          item = { 'class' => JobWrapper,
                   'queue' => job.queue_name,
                   'args' => [job, *args],
                   'retry' => true }
          Sidekiq::Client.push(item)
        end
      end

      class JobWrapper
        include Sidekiq::Worker

        def perform(job_name, *args)
          instance = job_name.constantize.new
          instance.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end
