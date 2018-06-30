# frozen_string_literal: true

require "active_support/core_ext/class/subclasses"
require "active_support/core_ext/hash/keys"

module ActiveJob
  # Provides helper methods for testing Active Job
  module TestHelper
    delegate :enqueued_jobs, :enqueued_jobs=,
      :performed_jobs, :performed_jobs=,
      to: :queue_adapter

    module TestQueueAdapter
      extend ActiveSupport::Concern

      included do
        class_attribute :_test_adapter, instance_accessor: false, instance_predicate: false
      end

      module ClassMethods
        def queue_adapter
          self._test_adapter.nil? ? super : self._test_adapter
        end

        def disable_test_adapter
          self._test_adapter = nil
        end

        def enable_test_adapter(test_adapter)
          self._test_adapter = test_adapter
        end
      end
    end

    ActiveJob::Base.include(TestQueueAdapter)

    def before_setup # :nodoc:
      test_adapter = queue_adapter_for_test

      queue_adapter_changed_jobs.each do |klass|
        klass.enable_test_adapter(test_adapter)
      end

      clear_enqueued_jobs
      clear_performed_jobs
      super
    end

    def after_teardown # :nodoc:
      super

      queue_adapter_changed_jobs.each { |klass| klass.disable_test_adapter }
    end

    # Specifies the queue adapter to use with all active job test helpers.
    #
    # Returns an instance of the queue adapter and defaults to
    # <tt>ActiveJob::QueueAdapters::TestAdapter</tt>.
    #
    # Note: The adapter provided by this method must provide some additional
    # methods from those expected of a standard <tt>ActiveJob::QueueAdapter</tt>
    # in order to be used with the active job test helpers. Refer to
    # <tt>ActiveJob::QueueAdapters::TestAdapter</tt>.
    def queue_adapter_for_test
      ActiveJob::QueueAdapters::TestAdapter.new
    end

    # Asserts that the number of enqueued jobs matches the given number.
    #
    #   def test_jobs
    #     assert_enqueued_jobs 0
    #     HelloJob.perform_later('david')
    #     assert_enqueued_jobs 1
    #     HelloJob.perform_later('abdelkader')
    #     assert_enqueued_jobs 2
    #   end
    #
    # If a block is passed, that block will cause the specified number of
    # jobs to be enqueued.
    #
    #   def test_jobs_again
    #     assert_enqueued_jobs 1 do
    #       HelloJob.perform_later('cristian')
    #     end
    #
    #     assert_enqueued_jobs 2 do
    #       HelloJob.perform_later('aaron')
    #       HelloJob.perform_later('rafael')
    #     end
    #   end
    #
    # The number of times a specific job was enqueued can be asserted.
    #
    #   def test_logging_job
    #     assert_enqueued_jobs 1, only: LoggingJob do
    #       LoggingJob.perform_later
    #       HelloJob.perform_later('jeremy')
    #     end
    #   end
    #
    # The number of times a job except specific class was enqueued can be asserted.
    #
    #   def test_logging_job
    #     assert_enqueued_jobs 1, except: HelloJob do
    #       LoggingJob.perform_later
    #       HelloJob.perform_later('jeremy')
    #     end
    #   end
    #
    # The number of times a job is enqueued to a specific queue can also be asserted.
    #
    #   def test_logging_job
    #     assert_enqueued_jobs 2, queue: 'default' do
    #       LoggingJob.perform_later
    #       HelloJob.perform_later('elfassy')
    #     end
    #   end
    def assert_enqueued_jobs(number, only: nil, except: nil, queue: nil)
      if block_given?
        original_count = enqueued_jobs_size(only: only, except: except, queue: queue)
        yield
        new_count = enqueued_jobs_size(only: only, except: except, queue: queue)
        assert_equal number, new_count - original_count, "#{number} jobs expected, but #{new_count - original_count} were enqueued"
      else
        actual_count = enqueued_jobs_size(only: only, except: except, queue: queue)
        assert_equal number, actual_count, "#{number} jobs expected, but #{actual_count} were enqueued"
      end
    end

    # Asserts that no jobs have been enqueued.
    #
    #   def test_jobs
    #     assert_no_enqueued_jobs
    #     HelloJob.perform_later('jeremy')
    #     assert_enqueued_jobs 1
    #   end
    #
    # If a block is passed, that block should not cause any job to be enqueued.
    #
    #   def test_jobs_again
    #     assert_no_enqueued_jobs do
    #       # No job should be enqueued from this block
    #     end
    #   end
    #
    # It can be asserted that no jobs of a specific kind are enqueued:
    #
    #   def test_no_logging
    #     assert_no_enqueued_jobs only: LoggingJob do
    #       HelloJob.perform_later('jeremy')
    #     end
    #   end
    #
    # It can be asserted that no jobs except specific class are enqueued:
    #
    #   def test_no_logging
    #     assert_no_enqueued_jobs except: HelloJob do
    #       HelloJob.perform_later('jeremy')
    #     end
    #   end
    #
    # Note: This assertion is simply a shortcut for:
    #
    #   assert_enqueued_jobs 0, &block
    def assert_no_enqueued_jobs(only: nil, except: nil, &block)
      assert_enqueued_jobs 0, only: only, except: except, &block
    end

    # Asserts that the number of performed jobs matches the given number.
    # If no block is passed, <tt>perform_enqueued_jobs</tt>
    # must be called around the job call.
    #
    #   def test_jobs
    #     assert_performed_jobs 0
    #
    #     perform_enqueued_jobs do
    #       HelloJob.perform_later('xavier')
    #     end
    #     assert_performed_jobs 1
    #
    #     perform_enqueued_jobs do
    #       HelloJob.perform_later('yves')
    #       assert_performed_jobs 2
    #     end
    #   end
    #
    # If a block is passed, that block should cause the specified number of
    # jobs to be performed.
    #
    #   def test_jobs_again
    #     assert_performed_jobs 1 do
    #       HelloJob.perform_later('robin')
    #     end
    #
    #     assert_performed_jobs 2 do
    #       HelloJob.perform_later('carlos')
    #       HelloJob.perform_later('sean')
    #     end
    #   end
    #
    # The block form supports filtering. If the :only option is specified,
    # then only the listed job(s) will be performed.
    #
    #     def test_hello_job
    #       assert_performed_jobs 1, only: HelloJob do
    #         HelloJob.perform_later('jeremy')
    #         LoggingJob.perform_later
    #       end
    #     end
    #
    # Also if the :except option is specified,
    # then the job(s) except specific class will be performed.
    #
    #     def test_hello_job
    #       assert_performed_jobs 1, except: LoggingJob do
    #         HelloJob.perform_later('jeremy')
    #         LoggingJob.perform_later
    #       end
    #     end
    #
    # An array may also be specified, to support testing multiple jobs.
    #
    #     def test_hello_and_logging_jobs
    #       assert_nothing_raised do
    #         assert_performed_jobs 2, only: [HelloJob, LoggingJob] do
    #           HelloJob.perform_later('jeremy')
    #           LoggingJob.perform_later('stewie')
    #           RescueJob.perform_later('david')
    #         end
    #       end
    #     end
    def assert_performed_jobs(number, only: nil, except: nil)
      if block_given?
        original_count = performed_jobs.size
        perform_enqueued_jobs(only: only, except: except) { yield }
        new_count = performed_jobs.size
        assert_equal number, new_count - original_count,
          "#{number} jobs expected, but #{new_count - original_count} were performed"
      else
        performed_jobs_size = performed_jobs.size
        assert_equal number, performed_jobs_size, "#{number} jobs expected, but #{performed_jobs_size} were performed"
      end
    end

    # Asserts that no jobs have been performed.
    #
    #   def test_jobs
    #     assert_no_performed_jobs
    #
    #     perform_enqueued_jobs do
    #       HelloJob.perform_later('matthew')
    #       assert_performed_jobs 1
    #     end
    #   end
    #
    # If a block is passed, that block should not cause any job to be performed.
    #
    #   def test_jobs_again
    #     assert_no_performed_jobs do
    #       # No job should be performed from this block
    #     end
    #   end
    #
    # The block form supports filtering. If the :only option is specified,
    # then only the listed job(s) will not be performed.
    #
    #   def test_no_logging
    #     assert_no_performed_jobs only: LoggingJob do
    #       HelloJob.perform_later('jeremy')
    #     end
    #   end
    #
    # Also if the :except option is specified,
    # then the job(s) except specific class will not be performed.
    #
    #   def test_no_logging
    #     assert_no_performed_jobs except: HelloJob do
    #       HelloJob.perform_later('jeremy')
    #     end
    #   end
    #
    # Note: This assertion is simply a shortcut for:
    #
    #   assert_performed_jobs 0, &block
    def assert_no_performed_jobs(only: nil, except: nil, &block)
      assert_performed_jobs 0, only: only, except: except, &block
    end

    # Asserts that the job has been enqueued with the given arguments.
    #
    #   def test_assert_enqueued_with
    #     MyJob.perform_later(1,2,3)
    #     assert_enqueued_with(job: MyJob, args: [1,2,3], queue: 'low')
    #
    #     MyJob.set(wait_until: Date.tomorrow.noon).perform_later
    #     assert_enqueued_with(job: MyJob, at: Date.tomorrow.noon)
    #   end
    #
    # If a block is passed, that block should cause the job to be
    # enqueued with the given arguments.
    #
    #   def test_assert_enqueued_with
    #     assert_enqueued_with(job: MyJob, args: [1,2,3], queue: 'low') do
    #       MyJob.perform_later(1,2,3)
    #     end
    #
    #     assert_enqueued_with(job: MyJob, at: Date.tomorrow.noon) do
    #       MyJob.set(wait_until: Date.tomorrow.noon).perform_later
    #     end
    #   end
    def assert_enqueued_with(job: nil, args: nil, at: nil, queue: nil)
      expected = { job: job, args: args, at: at, queue: queue }.compact
      serialized_args = serialize_args_for_assertion(expected)

      if block_given?
        original_enqueued_jobs_count = enqueued_jobs.count

        yield

        jobs = enqueued_jobs.drop(original_enqueued_jobs_count)
      else
        jobs = enqueued_jobs
      end

      matching_job = jobs.find do |enqueued_job|
        serialized_args.all? { |key, value| value == enqueued_job[key] }
      end

      assert matching_job, "No enqueued job found with #{expected}"
      instantiate_job(matching_job)
    end

    # Asserts that the job passed in the block has been performed with the given arguments.
    #
    #   def test_assert_performed_with
    #     assert_performed_with(job: MyJob, args: [1,2,3], queue: 'high') do
    #       MyJob.perform_later(1,2,3)
    #     end
    #
    #     assert_performed_with(job: MyJob, at: Date.tomorrow.noon) do
    #       MyJob.set(wait_until: Date.tomorrow.noon).perform_later
    #     end
    #   end
    def assert_performed_with(job: nil, args: nil, at: nil, queue: nil)
      original_performed_jobs_count = performed_jobs.count
      expected = { job: job, args: args, at: at, queue: queue }.compact
      serialized_args = serialize_args_for_assertion(expected)
      perform_enqueued_jobs { yield }
      in_block_jobs = performed_jobs.drop(original_performed_jobs_count)
      matching_job = in_block_jobs.find do |in_block_job|
        serialized_args.all? { |key, value| value == in_block_job[key] }
      end
      assert matching_job, "No performed job found with #{expected}"
      instantiate_job(matching_job)
    end

    # Performs all enqueued jobs in the duration of the block.
    #
    #   def test_perform_enqueued_jobs
    #     perform_enqueued_jobs do
    #       MyJob.perform_later(1, 2, 3)
    #     end
    #     assert_performed_jobs 1
    #   end
    #
    # This method also supports filtering. If the +:only+ option is specified,
    # then only the listed job(s) will be performed.
    #
    #   def test_perform_enqueued_jobs_with_only
    #     perform_enqueued_jobs(only: MyJob) do
    #       MyJob.perform_later(1, 2, 3) # will be performed
    #       HelloJob.perform_later(1, 2, 3) # will not be performed
    #     end
    #     assert_performed_jobs 1
    #   end
    #
    # Also if the +:except+ option is specified,
    # then the job(s) except specific class will be performed.
    #
    #   def test_perform_enqueued_jobs_with_except
    #     perform_enqueued_jobs(except: HelloJob) do
    #       MyJob.perform_later(1, 2, 3) # will be performed
    #       HelloJob.perform_later(1, 2, 3) # will not be performed
    #     end
    #     assert_performed_jobs 1
    #   end
    #
    def perform_enqueued_jobs(only: nil, except: nil)
      validate_option(only: only, except: except)
      old_perform_enqueued_jobs = queue_adapter.perform_enqueued_jobs
      old_perform_enqueued_at_jobs = queue_adapter.perform_enqueued_at_jobs
      old_filter = queue_adapter.filter
      old_reject = queue_adapter.reject

      begin
        queue_adapter.perform_enqueued_jobs = true
        queue_adapter.perform_enqueued_at_jobs = true
        queue_adapter.filter = only
        queue_adapter.reject = except
        yield
      ensure
        queue_adapter.perform_enqueued_jobs = old_perform_enqueued_jobs
        queue_adapter.perform_enqueued_at_jobs = old_perform_enqueued_at_jobs
        queue_adapter.filter = old_filter
        queue_adapter.reject = old_reject
      end
    end

    # Accesses the queue_adapter set by ActiveJob::Base.
    #
    #   def test_assert_job_has_custom_queue_adapter_set
    #     assert_instance_of CustomQueueAdapter, HelloJob.queue_adapter
    #   end
    def queue_adapter
      ActiveJob::Base.queue_adapter
    end

    private
      def clear_enqueued_jobs
        enqueued_jobs.clear
      end

      def clear_performed_jobs
        performed_jobs.clear
      end

      def enqueued_jobs_size(only: nil, except: nil, queue: nil)
        validate_option(only: only, except: except)
        enqueued_jobs.count do |job|
          job_class = job.fetch(:job)
          if only
            next false unless Array(only).include?(job_class)
          elsif except
            next false if Array(except).include?(job_class)
          end
          if queue
            next false unless queue.to_s == job.fetch(:queue, job_class.queue_name)
          end
          true
        end
      end

      def serialize_args_for_assertion(args)
        args.dup.tap do |serialized_args|
          serialized_args[:args] = ActiveJob::Arguments.serialize(serialized_args[:args]) if serialized_args[:args]
          serialized_args[:at]   = serialized_args[:at].to_f if serialized_args[:at]
        end
      end

      def instantiate_job(payload)
        job = payload[:job].new(*payload[:args])
        job.scheduled_at = Time.at(payload[:at]) if payload.key?(:at)
        job.queue_name = payload[:queue]
        job
      end

      def queue_adapter_changed_jobs
        (ActiveJob::Base.descendants << ActiveJob::Base).select do |klass|
          # only override explicitly set adapters, a quirk of `class_attribute`
          klass.singleton_class.public_instance_methods(false).include?(:_queue_adapter)
        end
      end

      def validate_option(only: nil, except: nil)
        raise ArgumentError, "Cannot specify both `:only` and `:except` options." if only && except
      end
  end
end
