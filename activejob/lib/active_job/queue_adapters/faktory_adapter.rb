# frozen_string_literal: true

require "faktory_worker_ruby"

module ActiveJob
  module QueueAdapters
    # == Faktory adapter for Active Job
    #
    # High-performance job processing for the polyglot enterprise.
    #
    # Read more about Faktory{here}[http://contribsys.com/faktory/].
    #
    # To use Faktory set the queue_adapter config to +:faktory+.
    #
    #   Rails.application.config.active_job.queue_adapter = :faktory
    class FaktoryAdapter
      def enqueue(job) #:nodoc:
        # Faktory::Client does not support symbols as keys
        job.provider_job_id = Faktory::Client.new.push \
          "jid"     => SecureRandom.hex(12),
          "jobtype" => JobWrapper,
          #"class"   => JobWrapper,
          "custom"  => {
            "wrapped" => job.class.to_s,
          },
          "queue"   => job.queue_name,
          "args"    => [ job.serialize ]
      end

      def enqueue_at(job, timestamp) #:nodoc:
        job.provider_job_id = Faktory::Client.new.push \
          "jid"     => SecureRandom.hex(12),
          "jobtype" => JobWrapper,
          #"class"   => JobWrapper,
          "custom"  => {
            "wrapped" => job.class.to_s
          },
          "queue"   => job.queue_name,
          "args"    => [ job.serialize ],
          "at"      => Time.at(timestamp).utc.to_datetime.rfc3339(9)
      end

      class JobWrapper #:nodoc:
        include Faktory::Job

        def perform(job_data)
          Base.execute job_data.merge("provider_job_id" => jid)
        end
      end
    end
  end
end
