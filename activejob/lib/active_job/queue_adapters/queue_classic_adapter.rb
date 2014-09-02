require 'queue_classic'

module ActiveJob
  module QueueAdapters
    class QueueClassicAdapter
      class << self
        def enqueue(job, *args)
          build_queue(job.queue_name).enqueue("#{JobWrapper.name}.perform", job.name, *args)
        end

        def enqueue_at(job, timestamp, *args)
          queue = build_queue(job.queue_name)
          unless queue.respond_to?(:enqueue_at)
            raise NotImplementedError, 'To be able to schedule jobs with Queue Classic ' \
              'the QC::Queue needs to respond to `enqueue_at(timestamp, method, *args)`. '
              'You can implement this yourself or you can use the queue_classic-later gem.'
          end
          queue.enqueue_at(timestamp, "#{JobWrapper.name}.perform", job.name, *args)
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

      class JobWrapper
        class << self
          def perform(job_name, *args)
            job_name.constantize.new.execute(*args)
          end
        end
      end
    end
  end
end
