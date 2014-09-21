require 'sucker_punch'

module ActiveJob
  module QueueAdapters
    # == Sucker Punch adapter for Active Job
    #
    # Sucker Punch is a single-process Ruby asynchronous processing library.
    # It's girl_friday and DSL sugar on top of Celluloid. With Celluloid's
    # actor pattern, we can do asynchronous processing within a single process.
    # This reduces costs of hosting on a service like Heroku along with the
    # memory footprint of having to maintain additional jobs if hosting on
    # a dedicated server. All queues can run within a single Rails/Sinatra
    # process.
    #
    # Read more about Sucker Punch {here}[https://github.com/brandonhilkert/sucker_punch].
    #
    # To use Sucker Punch set the queue_adapter config to +:sucker_punch+.
    #
    #   Rails.application.config.active_job.queue_adapter = :sucker_punch
    class SuckerPunchAdapter
      class << self
        def enqueue(job) #:nodoc:
          JobWrapper.new.async.perform job.serialize
        end

        def enqueue_at(job, timestamp) #:nodoc:
          raise NotImplementedError
        end
      end

      class JobWrapper #:nodoc:
        include SuckerPunch::Job

        def perform(job_data)
          Base.execute job_data
        end
      end
    end
  end
end
