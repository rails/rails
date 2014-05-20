require 'sidekiq'

module ActiveJob
  module QueueAdapters
    class SidekiqAdapter
      class << self
        def queue(job, *args)
          item = { 'class' => JobWrapper, 'queue' => job.queue_name, 'args' => [job, *args] }
          Sidekiq::Client.push(job.get_sidekiq_options.merge(item))
        end
      end

      class JobWrapper
        include Sidekiq::Worker

        def perform(job_name, *args)
          instance = job_name.constantize.new
          instance.jid = self.jid
          instance.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end

class ActiveJob::Base
  include Sidekiq::Worker
end
