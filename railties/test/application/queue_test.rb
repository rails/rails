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

    test "the queue is a TestQueue in test mode" do
      app("test")
      assert_kind_of ActiveSupport::TestQueue, Rails.application.queue[:default]
      assert_kind_of ActiveSupport::TestQueue, Rails.queue[:default]
    end

    test "the queue is a SynchronousQueue in development mode" do
      app("development")
      assert_kind_of ActiveSupport::SynchronousQueue, Rails.application.queue[:default]
      assert_kind_of ActiveSupport::SynchronousQueue, Rails.queue[:default]
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

    test "in development mode, an enqueued job will be processed in a separate thread" do
      app("development")

      job = ThreadTrackingJob.new
      Rails.queue.push job
      sleep 0.1

      assert job.ran?, "Expected job to be run"
      assert job.ran_in_different_thread?, "Expected job to run in the same thread"
    end

    test "in test mode, explicitly draining the queue will process it in a separate thread" do
      app("test")

      Rails.queue.push ThreadTrackingJob.new
      job = Rails.queue.jobs.last
      Rails.queue.drain

      assert job.ran?, "Expected job to be run"
      assert job.ran_in_different_thread?, "Expected job to run in a different thread"
    end

    class IdentifiableJob
      def initialize(id)
        @id = id
      end

      def ==(other)
        other.same_id?(@id)
      end

      def same_id?(other_id)
        other_id == @id
      end

      def run
      end
    end

    test "in test mode, the queue can be observed" do
      app("test")

      jobs = (1..10).map do |id|
        IdentifiableJob.new(id)
      end

      jobs.each do |job|
        Rails.queue.push job
      end

      assert_equal jobs, Rails.queue.jobs
    end

    test "in test mode, adding an unmarshallable job will raise an exception" do
      app("test")
      anonymous_class_instance = Struct.new(:run).new
      assert_raises TypeError do
        Rails.queue.push anonymous_class_instance
      end
    end

    test "attempting to marshal a queue will raise an exception" do
      app("test")
      assert_raises TypeError do
        Marshal.dump Rails.queue
      end
    end

    test "attempting to add a reference to itself to the queue will raise an exception" do
      app("test")
      job = {reference: Rails.queue}
      assert_raises TypeError do
        Rails.queue.push job
      end
    end

    def setup_custom_queue
      add_to_env_config "production", <<-RUBY
        require "my_queue"
        config.queue = MyQueue
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

      assert_kind_of MyQueue, Rails.queue[:default]

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
        config.queue = ActiveSupport::Queue
        config.queue_consumer = MyQueueConsumer
      RUBY

      app_file "lib/my_queue_consumer.rb", <<-RUBY
        class MyQueueConsumer < ActiveSupport::ThreadedQueueConsumer
          attr_reader :started

          def start
            @started = true
            self
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
