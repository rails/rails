# frozen_string_literal: true

require 'sneakers'
require 'monitor'

module ActiveJob
  module QueueAdapters
    # == Sneakers adapter for Active Job
    #
    # A high-performance RabbitMQ background processing framework for Ruby.
    # Sneakers is being used in production for both I/O and CPU intensive
    # workloads, and have achieved the goals of high-performance and
    # 0-maintenance, as designed.
    #
    # Read more about Sneakers {here}[https://github.com/jondot/sneakers].
    #
    # To use Sneakers set the queue_adapter config to +:sneakers+.
    #
    #   Rails.application.config.active_job.queue_adapter = :sneakers
    class SneakersAdapter
      def initialize
        @monitor = Monitor.new
      end

      def enqueue(job) #:nodoc:
        @monitor.synchronize do
          JobWrapper.from_queue job.queue_name
          JobWrapper.enqueue ActiveSupport::JSON.encode(job.serialize)
        end
      end

      def enqueue_at(job, timestamp) #:nodoc:
        raise NotImplementedError, 'This queueing backend does not support scheduling jobs. To see what features are supported go to http://api.rubyonrails.org/classes/ActiveJob/QueueAdapters.html'
      end

      class JobWrapper #:nodoc:
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
