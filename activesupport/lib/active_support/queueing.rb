require 'delegate'
require 'thread'

module ActiveSupport
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

    # Drain the queue, running all jobs in a different thread. This method
    # may not be available on production queues.
    def drain
      # run the jobs in a separate thread so assumptions of synchronous
      # jobs are caught in test mode.
      consumer.drain
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
      @que.dup
    end

    # Marshal and unmarshal job before pushing it onto the queue.  This will
    # raise an exception on any attempts in tests to push jobs that can't (or
    # shouldn't) be marshalled.
    def push(job)
      super Marshal.load(Marshal.dump(job))
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
