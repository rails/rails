require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class GeneratorsTest < ActiveSupport::TestCase
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
      assert_kind_of Rails::Queueing::TestQueue, Rails.application.queue
      assert_kind_of Rails::Queueing::TestQueue, Rails.queue
    end

    test "the queue is a Queue in development mode" do
      app("development")
      assert_kind_of Rails::Queueing::Queue, Rails.application.queue
      assert_kind_of Rails::Queueing::Queue, Rails.queue
    end

    test "in development mode, an enqueued job will be processed in a separate thread" do
      app("development")

      job = Struct.new(:origin, :target).new(Thread.current)
      def job.run
        self.target = Thread.current
      end

      Rails.queue.push job
      sleep 0.1

      assert job.target, "The job was run"
      assert_not_equal job.origin, job.target
    end

    test "in test mode, explicitly draining the queue will process it in a separate thread" do
      app("test")

      job = Struct.new(:origin, :target).new(Thread.current)
      def job.run
        self.target = Thread.current
      end

      Rails.queue.push job
      Rails.queue.drain

      assert job.target, "The job was run"
      assert_not_equal job.origin, job.target
    end

    test "in test mode, the queue can be observed" do
      app("test")

      job = Struct.new(:id) do
        def run
        end
      end

      jobs = (1..10).map do |id|
        job.new(id)
      end

      jobs.each do |job|
        Rails.queue.push job
      end

      assert_equal jobs, Rails.queue.jobs
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
        config.queue_consumer = MyQueueConsumer
      RUBY

      app_file "lib/my_queue_consumer.rb", <<-RUBY
        class MyQueueConsumer < Rails::Queueing::ThreadedConsumer
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
