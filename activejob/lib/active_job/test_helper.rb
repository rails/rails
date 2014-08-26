# encoding: utf-8
module ActiveJob
  # Provides helper methods for testing Active Job
  module TestHelper
    # Asserts that the number of enqueued jobs matches the given number.
    #
    #   def test_jobs
    #     assert_enqueued_jobs 0
    #     HelloJob.enqueue('david')
    #     assert_enqueued_jobs 1
    #     HelloJob.enqueue('abdelkader')
    #     assert_enqueued_jobs 2
    #   end
    #
    # If a block is passed, that block should cause the specified number of
    # jobs to be enqueued.
    #
    #   def test_jobs_again
    #     assert_enqueued_jobs 1 do
    #       HelloJob.enqueue('cristian')
    #     end
    #
    #     assert_enqueued_jobs 2 do
    #       HelloJob.enqueue('aaron')
    #       HelloJob.enqueue('rafael')
    #     end
    #   end
    def assert_enqueued_jobs(number)
      if block_given?
        original_count = enqueued_jobs.size
        yield
        new_count = enqueued_jobs.size
        assert_equal original_count + number, new_count,
                     "#{number} job expected, but #{new_count - original_count} were enqueued"
      else
        assert_equal number, enqueued_jobs.size
      end
    end

    # Assert that no job have been enqueued.
    #
    #   def test_jobs
    #     assert_no_enqueued_jobs
    #     HelloJob.enqueue('jeremy')
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
    #   assert_enqueued_jobs 0
    def assert_no_enqueued_jobs(&block)
      assert_enqueued_jobs 0, &block
    end

    # Asserts that the number of performed jobs matches the given number.
    #
    #   def test_jobs
    #     assert_performed_jobs 0
    #     HelloJob.enqueue('xavier')
    #     assert_performed_jobs 1
    #     HelloJob.enqueue('yves')
    #     assert_performed_jobs 2
    #   end
    #
    # If a block is passed, that block should cause the specified number of
    # jobs to be performed.
    #
    #   def test_jobs_again
    #     assert_performed_jobs 1 do
    #       HelloJob.enqueue('robin')
    #     end
    #
    #     assert_performed_jobs 2 do
    #       HelloJob.enqueue('carlos')
    #       HelloJob.enqueue('sean')
    #     end
    #   end
    def assert_performed_jobs(number)
      if block_given?
        original_count = self.class.job_class.performed_jobs.size
        yield
        new_count = performed_jobs.size
        assert_equal original_count + number, new_count,
                     "#{number} job expected, but #{new_count - original_count} were performed"
      else
        assert_equal number, performed_jobs.size
      end
    end

    # Assert that no job have been performed.
    #
    #   def test_jobs
    #     assert_no_performed_jobs
    #     HelloJob.enqueue('matthew')
    #     assert_performed_jobs 1
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
    #   assert_performed_jobs 0
    def assert_no_performed_jobs(&block)
      assert_performed_jobs 0, &block
    end

    # Assert that a job was enqueued in the block matches the args
    #
    #   def assert_enqueued_job
    #     assert_enqueued_job(job: MyJob, args: [1,2,3], queue: 'low') do
    #       MyJob.enqueue(1,2,3)
    #     end
    #   end
    def assert_enqueued_job(args = {}, &_block)
      original_enqueued_jobs = enqueued_jobs
      enqueued_jobs.clear
      args.assert_valid_keys(:job, :args, :at, :queue)
      yield
      matching_job = enqueued_jobs.any? do |job|
        args.all?  { |key, value| value ==  job[key] }
      end
      assert matching_job
    ensure
      ActiveJob::Base.enqueued_jobs = original_enqueued_jobs + enqueued_jobs
    end

    # Assert that a job was performed in the block matches the args
    #
    #   def assert_performed_job
    #     assert_performed_job(job: MyJob, args: [1,2,3], queue: 'high') do
    #       MyJob.enqueue(1,2,3)
    #     end
    #   end
    def assert_performed_job(args = {}, &_block)
      original_performed_jobs = performed_jobs
      performed_jobs.clear
      args.assert_valid_keys(:job, :args, :at, :queue)
      yield
      matching_job = performed_jobs.any? do |job|
        args.all?  { |key, value| value ==  job[key] }
      end
      assert matching_job, "No performed job found with #{args}"
    ensure
      ActiveJob::Base.performed_jobs = original_performed_jobs + performed_jobs
    end

    private
      def enqueued_jobs
        ActiveJob::Base.enqueued_jobs
      end

      def performed_jobs
        ActiveJob::Base.performed_jobs
      end
  end
end
