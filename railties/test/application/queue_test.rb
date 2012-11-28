require 'isolation/abstract_unit'

module ApplicationTests
  class QueueTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    def app_const
      @app_const ||= Class.new(Rails::Application)
    end

    test "the queue is a SynchronousQueue in test mode" do
      app("test")
      assert_kind_of ActiveSupport::SynchronousQueue, Rails.application.queue
      assert_kind_of ActiveSupport::SynchronousQueue, Rails.queue
    end

    test "the queue is a SynchronousQueue in development mode" do
      app("development")
      assert_kind_of ActiveSupport::SynchronousQueue, Rails.application.queue
      assert_kind_of ActiveSupport::SynchronousQueue, Rails.queue
    end

    class ThreadTrackingJob
      def initialize
        @origin = Thread.current.object_id
      end

      def run
        @target = Thread.current.object_id
      end

      def ran_in_different_thread?
        @origin != @target
      end

      def ran?
        @target
      end
    end

    test "in development mode, an enqueued job will be processed in the same thread" do
      app("development")

      job = ThreadTrackingJob.new
      Rails.queue.push job
      sleep 0.1

      assert job.ran?, "Expected job to be run"
      refute job.ran_in_different_thread?, "Expected job to run in the same thread"
    end

    test "in test mode, an enqueued job will be processed in the same thread" do
      app("test")

      job = ThreadTrackingJob.new
      Rails.queue.push job
      sleep 0.1

      assert job.ran?, "Expected job to be run"
      refute job.ran_in_different_thread?, "Expected job to run in the same thread"
    end

    test "in production, automatically spawn a queue consumer in a background thread" do
      add_to_env_config "production", <<-RUBY
        config.queue = ActiveSupport::Queue.new
      RUBY

      app("production")

      assert_nil Rails.application.config.queue_consumer
      assert_kind_of ActiveSupport::ThreadedQueueConsumer, Rails.application.queue_consumer
      assert_equal Rails.logger, Rails.application.queue_consumer.logger
    end

    test "attempting to marshal a queue will raise an exception" do
      app("test")
      assert_raises TypeError do
        Marshal.dump Rails.queue
      end
    end

    def setup_custom_queue
      add_to_env_config "production", <<-RUBY
        require "my_queue"
        config.queue = MyQueue.new
      RUBY

      app_file "lib/my_queue.rb", <<-RUBY
        class MyQueue
          def push(job)
            job.run
          end
        end
      RUBY

      app("production")
    end

    test "a custom queue implementation can be provided" do
      setup_custom_queue

      assert_kind_of MyQueue, Rails.queue

      job = Struct.new(:id, :ran) do
        def run
          self.ran = true
        end
      end

      job1 = job.new(1)
      Rails.queue.push job1

      assert_equal true, job1.ran
    end

    test "a custom consumer implementation can be provided" do
      add_to_env_config "production", <<-RUBY
        require "my_queue_consumer"
        config.queue = ActiveSupport::Queue.new
        config.queue_consumer = MyQueueConsumer.new
      RUBY

      app_file "lib/my_queue_consumer.rb", <<-RUBY
        class MyQueueConsumer
          attr_reader :started

          def start
            @started = true
          end
        end
      RUBY

      app("production")

      assert_kind_of MyQueueConsumer, Rails.application.queue_consumer
      assert Rails.application.queue_consumer.started
    end

    test "default consumer is not used with custom queue implementation" do
      setup_custom_queue

      assert_nil Rails.application.queue_consumer
    end
  end
end
