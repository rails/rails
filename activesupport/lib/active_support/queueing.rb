require 'delegate'
require 'thread'
require 'active_support/hash_with_indifferent_access'

module ActiveSupport

  class JobPayloadizer

    def self.payload_from_job(job)
      if job.is_a?(Class)
        return job.name
      end
      if job.nil?
        return job
      end
      unless job.respond_to?(:to_serializable_hash)
        raise TypeError, "Please implement to_serializable_hash on #{job.inspect}"
      end
      unless job.class.respond_to?(:from_serializable_hash)
        raise TypeError, "Please implement #{job.class}.from_serializable_hash"
      end
      {'job_class' => job.class.name, 'object_hash' => job.to_serializable_hash}
    end

    def self.job_from_payload(payload)
      if payload.nil?
        return payload
      end
      unless payload.is_a?(Hash)
        return payload.constantize
      end
      job_class = payload["job_class"].constantize
      object_hash = HashWithIndifferentAccess.new(payload["object_hash"])
      job_class.from_serializable_hash(object_hash)
    end

    def self.unconstantize
      self.name.to_s
    end

  end

  class MarshalEncoder
    def self.encode(object)
      Marshal.dump(object)
    end
    def self.decode(encoded_object)
      Marshal.load(encoded_object)
    end
  end

  # A Queue that simply inherits from STDLIB's Queue. When this
  # queue is used, Rails automatically starts a job runner in a
  # background thread.
  class Queue < ::Queue
    attr_writer :consumer

    def initialize(consumer_options = {})
      super()
      @consumer_options = consumer_options
    end

    def consumer
      @consumer ||= ThreadedQueueConsumer.new(self, @consumer_options)
    end

    def default_payloadizer
      @payloadizer ||= JobPayloadizer
    end

    def encoder
      # but perhaps ActiveSupport::JSON would be a better default
      @encoder ||= MarshalEncoder
    end

    # Drain the queue, running all jobs in a different thread. This method
    # may not be available on production queues.
    def drain
      # run the jobs in a separate thread so assumptions of synchronous
      # jobs are caught in test mode.
      consumer.drain
    end

    def pop
      joberize(super)
    end

    def push(job)
      #Jobs must define their own payloadizer, or implement to_serializable_hash / from_serializable_hash
      payloadizer = job.respond_to?(:payloadizer) ? job.payloadizer : default_payloadizer
      payload = payloadizer.payload_from_job(job)
      super encoder.encode({'payloadizer' => payloadizer.unconstantize, 'payload' => payload})
    end

    protected

    def joberize(payload)
      job_data = encoder.decode(payload)
      job_data["payloadizer"].constantize.job_from_payload(job_data["payload"])
    end

  end

  class SynchronousQueue < Queue
    def push(job)
      super.tap { drain }
    end
    alias <<  push
    alias enq push
  end

  # In test mode, the Rails queue is backed by an Array so that assertions
  # can be made about its contents. The test queue provides a +jobs+
  # method to make assertions about the queue's contents and a +drain+
  # method to drain the queue and run the jobs.
  #
  # Jobs are run in a separate thread to catch mistakes where code
  # assumes that the job is run in the same thread.
  class TestQueue < Queue
    # Get a list of the jobs off this queue. This method may not be
    # available on production queues.
    def jobs
      @que.dup.map{ |job_data| joberize(job_data) }
    end
  end

  # The threaded consumer will run jobs in a background thread in
  # development mode or in a VM where running jobs on a thread in
  # production mode makes sense.
  #
  # When the process exits, the consumer pushes a nil onto the
  # queue and joins the thread, which will ensure that all jobs
  # are executed before the process finally dies.
  class ThreadedQueueConsumer
    attr_accessor :logger

    def initialize(queue, options = {})
      @queue = queue
      @logger = options[:logger]
      @fallback_logger = Logger.new($stderr)
    end

    def start
      @thread = Thread.new { consume }
      self
    end

    def shutdown
      @queue.push nil
      @thread.join
    end

    def drain
      @queue.pop.run until @queue.empty?
    end

    def consume
      while job = @queue.pop
        run job
      end
    end

    def run(job)
      job.run
    rescue Exception => exception
      handle_exception job, exception
    end

    def handle_exception(job, exception)
      (logger || @fallback_logger).error "Job Error: #{job.inspect}\n#{exception.message}\n#{exception.backtrace.join("\n")}"
    end
  end
end
