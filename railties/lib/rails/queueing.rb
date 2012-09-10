require "thread"
require 'delegate'

module Rails
  module Queueing
    # A container for multiple queues. This class delegates to a default Queue
    # so that <tt>Rails.queue.push</tt> and friends will Just Work. To use this class
    # with multiple queues:
    #
    #   # In your configuration:
    #   Rails.queue[:image_queue] = SomeQueue.new
    #   Rails.queue[:mail_queue]  = SomeQueue.new
    #
    #   # In your app code:
    #   Rails.queue[:mail_queue].push SomeJob.new
    #
    class Container < DelegateClass(::Queue)
      def initialize(default_queue)
        @queues = { :default => default_queue }
        super(default_queue)
      end

      def [](queue_name)
        @queues[queue_name]
      end

      def []=(queue_name, queue)
        @queues[queue_name] = queue
      end
    end

    # A Queue that simply inherits from STDLIB's Queue. Everytime this
    # queue is used, Rails automatically sets up a ThreadedConsumer
    # to consume it.
    class Queue < ::Queue
    end

    class SynchronousQueue < ::Queue
      def push(job)
        job.run
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
    class TestQueue < ::Queue
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

      # Drain the queue, running all jobs in a different thread. This method
      # may not be available on production queues.
      def drain
        # run the jobs in a separate thread so assumptions of synchronous
        # jobs are caught in test mode.
        Thread.new { pop.run until empty? }.join
      end
    end

    # The threaded consumer will run jobs in a background thread in
    # development mode or in a VM where running jobs on a thread in
    # production mode makes sense.
    #
    # When the process exits, the consumer pushes a nil onto the
    # queue and joins the thread, which will ensure that all jobs
    # are executed before the process finally dies.
    class ThreadedConsumer
      def self.start(queue)
        new(queue).start
      end

      def initialize(queue)
        @queue = queue
      end

      def start
        @thread = Thread.new do
          while job = @queue.pop
            begin
              job.run
            rescue Exception => e
              handle_exception e
            end
          end
        end
        self
      end

      def shutdown
        @queue.push nil
        @thread.join
      end

      def handle_exception(e)
        Rails.logger.error "Job Error: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end
