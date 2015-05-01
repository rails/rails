require 'active_support/core_ext/hash/keys'

module ActiveJob
  # Provides helper methods for testing Active Job
  module TestHelper
    extend ActiveSupport::Concern

    included do
      def before_setup
        @old_queue_adapter  = queue_adapter
        ActiveJob::Base.queue_adapter = :test
        clear_enqueued_jobs
        clear_performed_jobs
        super
      end

      def after_teardown
        super
        ActiveJob::Base.queue_adapter = @old_queue_adapter
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
      # If a block is passed, that block should cause the specified number of
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
      def assert_enqueued_jobs(number)
        if block_given?
          original_count = enqueued_jobs.size
          yield
          new_count = enqueued_jobs.size
          assert_equal number, new_count - original_count,
                       "#{number} jobs expected, but #{new_count - original_count} were enqueued"
        else
          enqueued_jobs_size = enqueued_jobs.size
          assert_equal number, enqueued_jobs_size, "#{number} jobs expected, but #{enqueued_jobs_size} were enqueued"
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
      # Note: This assertion is simply a shortcut for:
      #
      #   assert_enqueued_jobs 0, &block
      def assert_no_enqueued_jobs(&block)
        assert_enqueued_jobs 0, &block
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
      def assert_performed_jobs(number)
        if block_given?
          original_count = performed_jobs.size
          perform_enqueued_jobs { yield }
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
      # Note: This assertion is simply a shortcut for:
      #
      #   assert_performed_jobs 0, &block
      def assert_no_performed_jobs(&block)
        assert_performed_jobs 0, &block
      end

      # Asserts that the job passed in the block has been enqueued with the given arguments.
      #
      #   def test_assert_enqueued_with
      #     assert_enqueued_with(job: MyJob, args: [1,2,3], queue: 'low') do
      #       MyJob.perform_later(1,2,3)
      #     end
      #   end
      def assert_enqueued_with(args = {}, &_block)
        original_enqueued_jobs = enqueued_jobs.dup
        clear_enqueued_jobs
        args.assert_valid_keys(:job, :args, :at, :queue)
        serialized_args = serialize_args_for_assertion(args)
        yield
        matching_job = enqueued_jobs.any? do |job|
          serialized_args.all? { |key, value| value == job[key] }
        end
        assert matching_job, "No enqueued job found with #{args}"
      ensure
        queue_adapter.enqueued_jobs = original_enqueued_jobs + enqueued_jobs
      end

      # Asserts that the job passed in the block has been performed with the given arguments.
      #
      #   def test_assert_performed_with
      #     assert_performed_with(job: MyJob, args: [1,2,3], queue: 'high') do
      #       MyJob.perform_later(1,2,3)
      #     end
      #   end
      def assert_performed_with(args = {}, &_block)
        original_performed_jobs = performed_jobs.dup
        clear_performed_jobs
        args.assert_valid_keys(:job, :args, :at, :queue)
        serialized_args = serialize_args_for_assertion(args)
        perform_enqueued_jobs { yield }
        matching_job = performed_jobs.any? do |job|
          serialized_args.all? { |key, value| value == job[key] }
        end
        assert matching_job, "No performed job found with #{args}"
      ensure
        queue_adapter.performed_jobs = original_performed_jobs + performed_jobs
      end

      def perform_enqueued_jobs
        @old_perform_enqueued_jobs = queue_adapter.perform_enqueued_jobs
        @old_perform_enqueued_at_jobs = queue_adapter.perform_enqueued_at_jobs
        queue_adapter.perform_enqueued_jobs = true
        queue_adapter.perform_enqueued_at_jobs = true
        yield
      ensure
        queue_adapter.perform_enqueued_jobs = @old_perform_enqueued_jobs
        queue_adapter.perform_enqueued_at_jobs = @old_perform_enqueued_at_jobs
      end

      def queue_adapter
        ActiveJob::Base.queue_adapter
      end

      delegate :enqueued_jobs, :enqueued_jobs=,
               :performed_jobs, :performed_jobs=,
               to: :queue_adapter

      private
        def clear_enqueued_jobs
          enqueued_jobs.clear
        end

        def clear_performed_jobs
          performed_jobs.clear
        end

        def serialize_args_for_assertion(args)
          serialized_args = args.dup
          if job_args = serialized_args.delete(:args)
            serialized_args[:args] = ActiveJob::Arguments.serialize(job_args)
          end
          serialized_args
        end
    end
  end
end
