require 'queue_classic'

module ActiveJob
  module QueueAdapters
    # == Queue Classic adapter for Active Job
    #
    # queue_classic provides a simple interface to a PostgreSQL-backed message
    # queue. queue_classic specializes in concurrent locking and minimizing
    # database load while providing a simple, intuitive developer experience.
    # queue_classic assumes that you are already using PostgreSQL in your
    # production environment and that adding another dependency (e.g. redis,
    # beanstalkd, 0mq) is undesirable.
    #
    # Read more about Queue Classic {here}[https://github.com/ryandotsmith/queue_classic].
    #
    # To use Queue Classic set the queue_adapter config to +:queue_classic+.
    #
    #   Rails.application.config.active_job.queue_adapter = :queue_classic
    class QueueClassicAdapter
      class << self
        def enqueue(job) #:nodoc:
          build_queue(job.queue_name).enqueue("#{JobWrapper.name}.perform", job.serialize)
        end

        def enqueue_at(job, timestamp) #:nodoc:
          queue = build_queue(job.queue_name)
          unless queue.respond_to?(:enqueue_at)
            raise NotImplementedError, 'To be able to schedule jobs with Queue Classic ' \
              'the QC::Queue needs to respond to `enqueue_at(timestamp, method, *args)`. '
              'You can implement this yourself or you can use the queue_classic-later gem.'
          end
          queue.enqueue_at(timestamp, "#{JobWrapper.name}.perform", job.serialize)
        end

        # Builds a <tt>QC::Queue</tt> object to schedule jobs on.
        #
        # If you have a custom <tt>QC::Queue</tt> subclass you'll need to suclass
        # <tt>ActiveJob::QueueAdapters::QueueClassicAdapter</tt> and override the
        # <tt>build_queue</tt> method.
        def build_queue(queue_name)
          QC::Queue.new(queue_name)
        end
      end

      class JobWrapper #:nodoc:
        class << self
          def perform(job_data)
            Base.execute job_data
          end
        end
      end
    end
  end
end
