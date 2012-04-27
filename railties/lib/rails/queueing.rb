module Rails
  module Queueing
    # In test mode, the Rails queue is backed by an Array so that assertions
    # can be made about its contents. The test queue provides a +contents+
    # method to make assertions about the queue's contents and a +drain+
    # method to drain the queue and run the jobs.
    #
    # Jobs are run in a separate thread to catch mistakes where code
    # assumes that the job is run in the same thread.
    class TestQueue
      attr_reader :contents

      def initialize
        @contents = []
      end

      def drain
        # run the jobs in a separate thread so assumptions of synchronous
        # jobs are caught in test mode.
        t = Thread.new do
          while job = @contents.pop
            job.run
          end
        end
        t.join
      end

      # implement the Queue API
      def push(object)
        @contents << object
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
            job.run
          end
        end
        self
      end

      def shutdown
        @queue.push nil
        @thread.join
      end
    end
  end
end
