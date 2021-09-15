# frozen_string_literal: true

require "queue_classic"

module ActiveJob
  module QueueAdapters
    # == queue_classic adapter for Active Job
    #
    # queue_classic provides a simple interface to a PostgreSQL-backed message
    # queue. queue_classic specializes in concurrent locking and minimizing
    # database load while providing a simple, intuitive developer experience.
    # queue_classic assumes that you are already using PostgreSQL in your
    # production environment and that adding another dependency (e.g. redis,
    # beanstalkd, 0mq) is undesirable.
    #
    # Read more about queue_classic {here}[https://github.com/QueueClassic/queue_classic].
    #
    # To use queue_classic set the queue_adapter config to +:queue_classic+.
    #
    #   Rails.application.config.active_job.queue_adapter = :queue_classic
    class QueueClassicAdapter
      def enqueue(job) # :nodoc:
        qc_job = build_queue(job.queue_name).enqueue("#{JobWrapper.name}.perform", job.serialize)
        job.provider_job_id = qc_job["id"] if qc_job.is_a?(Hash)
        qc_job
      end

      def enqueue_at(job, timestamp) # :nodoc:
        queue = build_queue(job.queue_name)
        unless queue.respond_to?(:enqueue_at)
          raise NotImplementedError, "To be able to schedule jobs with queue_classic " \
            "the QC::Queue needs to respond to `enqueue_at(timestamp, method, *args)`. " \
            "You can implement this yourself or you can use the queue_classic-later gem."
        end
        qc_job = queue.enqueue_at(timestamp, "#{JobWrapper.name}.perform", job.serialize)
        job.provider_job_id = qc_job["id"] if qc_job.is_a?(Hash)
        qc_job
      end

      # Builds a <tt>QC::Queue</tt> object to schedule jobs on.
      #
      # If you have a custom <tt>QC::Queue</tt> subclass you'll need to subclass
      # <tt>ActiveJob::QueueAdapters::QueueClassicAdapter</tt> and override the
      # <tt>build_queue</tt> method.
      def build_queue(queue_name)
        QC::Queue.new(queue_name)
      end

      class JobWrapper # :nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
