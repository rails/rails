# frozen_string_literal: true

require "helper"
require "jobs/retry_job"
require "jobs/after_discard_retry_job"
require "models/person"
require "minitest/mock"

class ExceptionsTest < ActiveSupport::TestCase
  class << self
    def adapter_skips_scheduling?(queue_adapter)
      [
        ActiveJob::QueueAdapters::InlineAdapter,
        ActiveJob::QueueAdapters::AsyncAdapter,
        ActiveJob::QueueAdapters::SneakersAdapter
      ].include?(queue_adapter.class)
    end
  end

  unless adapter_skips_scheduling?(ActiveJob::Base.queue_adapter)
    setup do
      JobBuffer.clear
    end

    test "successfully retry job throwing exception against defaults" do
      RetryJob.perform_later "DefaultsError", 5

      assert_equal [
        "Raised DefaultsError for the 1st time",
        "Raised DefaultsError for the 2nd time",
        "Raised DefaultsError for the 3rd time",
        "Raised DefaultsError for the 4th time",
        "Successfully completed job" ], JobBuffer.values
    end

    test "successfully retry job throwing exception against higher limit" do
      RetryJob.perform_later "ShortWaitTenAttemptsError", 9
      assert_equal 9, JobBuffer.values.count
    end

    test "keeps the same attempts counter for several exceptions listed in the same retry_on declaration" do
      exceptions_to_raise = %w(FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo
                               SecondRetryableErrorOfTwo SecondRetryableErrorOfTwo)

      assert_raises SecondRetryableErrorOfTwo do
        RetryJob.perform_later(exceptions_to_raise, 5)
      end

      assert_equal [
        "Raised FirstRetryableErrorOfTwo for the 1st time",
        "Raised FirstRetryableErrorOfTwo for the 2nd time",
        "Raised FirstRetryableErrorOfTwo for the 3rd time",
        "Raised SecondRetryableErrorOfTwo for the 4th time"
      ], JobBuffer.values
    end

    test "keeps a separate attempts counter for each individual retry_on declaration" do
      exceptions_to_raise = %w(DefaultsError DefaultsError DefaultsError DefaultsError
                               FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo FirstRetryableErrorOfTwo)

      assert_nothing_raised do
        RetryJob.perform_later(exceptions_to_raise, 10)

        assert_equal [
          "Raised DefaultsError for the 1st time",
          "Raised DefaultsError for the 2nd time",
          "Raised DefaultsError for the 3rd time",
          "Raised DefaultsError for the 4th time",
          "Raised FirstRetryableErrorOfTwo for the 5th time",
          "Raised FirstRetryableErrorOfTwo for the 6th time",
          "Raised FirstRetryableErrorOfTwo for the 7th time",
          "Successfully completed job"
        ], JobBuffer.values
      end
    end

    test "failed retry job when exception kept occurring against defaults" do
      RetryJob.perform_later "DefaultsError", 6
      assert_equal "Raised DefaultsError for the 5th time", JobBuffer.last_value
    rescue DefaultsError
      pass
    end

    test "failed retry job when exception kept occurring against higher limit" do
      RetryJob.perform_later "ShortWaitTenAttemptsError", 11
      assert_equal "Raised ShortWaitTenAttemptsError for the 10th time", JobBuffer.last_value
    rescue ShortWaitTenAttemptsError
      pass
    end

    test "discard job" do
      RetryJob.perform_later "DiscardableError", 2
      assert_equal "Raised DiscardableError for the 1st time", JobBuffer.last_value
    end

    test "custom handling of discarded job" do
      RetryJob.perform_later "CustomDiscardableError", 2
      assert_equal "Dealt with a job that was discarded in a custom way. Message: CustomDiscardableError", JobBuffer.last_value
    end

    test "custom handling of job that exceeds retry attempts" do
      RetryJob.perform_later "CustomCatchError", 6
      assert_equal "Dealt with a job that failed to retry in a custom way after 6 attempts. Message: CustomCatchError", JobBuffer.last_value
    end

    test "long wait job" do
      travel_to Time.now
      random_amount = 1
      delay_for_jitter = random_amount * 3600 * ActiveJob::Base.retry_jitter

      Kernel.stub(:rand, random_amount) do
        RetryJob.perform_later "LongWaitError", 2, :log_scheduled_at
        assert_equal [
          "Raised LongWaitError for the 1st time",
          "Next execution scheduled at #{(Time.now + 3600.seconds + delay_for_jitter).to_f}",
          "Successfully completed job"
        ], JobBuffer.values
      end
    end

    test "polynomially retrying job includes jitter" do
      travel_to Time.now

      random_amount = 2
      delay_for_jitter = -> (delay) { random_amount * delay * ActiveJob::Base.retry_jitter }

      Kernel.stub(:rand, random_amount) do
        RetryJob.perform_later "PolynomialWaitTenAttemptsError", 5, :log_scheduled_at

        assert_equal [
          "Raised PolynomialWaitTenAttemptsError for the 1st time",
          "Next execution scheduled at #{(Time.now + 3.seconds + delay_for_jitter.(1)).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 2nd time",
          "Next execution scheduled at #{(Time.now + 18.seconds + delay_for_jitter.(16)).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 3rd time",
          "Next execution scheduled at #{(Time.now + 83.seconds + delay_for_jitter.(81)).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 4th time",
          "Next execution scheduled at #{(Time.now + 258.seconds + delay_for_jitter.(256)).to_f}",
          "Successfully completed job"
        ], JobBuffer.values
      end
    end

    test "retry jitter uses value from ActiveJob::Base.retry_jitter by default" do
      old_jitter = ActiveJob::Base.retry_jitter
      ActiveJob::Base.retry_jitter = 4.0

      travel_to Time.now

      random_amount = 1

      Kernel.stub(:rand, random_amount) do
        RetryJob.perform_later "PolynomialWaitTenAttemptsError", 5, :log_scheduled_at

        assert_equal [
          "Raised PolynomialWaitTenAttemptsError for the 1st time",
          "Next execution scheduled at #{(Time.now + 7.seconds).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 2nd time",
          "Next execution scheduled at #{(Time.now + 82.seconds).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 3rd time",
          "Next execution scheduled at #{(Time.now + 407.seconds).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 4th time",
          "Next execution scheduled at #{(Time.now + 1282.seconds).to_f}",
          "Successfully completed job"
        ], JobBuffer.values
      end
    ensure
      ActiveJob::Base.retry_jitter = old_jitter
    end

    test "random wait time for default job when retry jitter delay multiplier value is between 1 and 2" do
      old_jitter = ActiveJob::Base.retry_jitter
      ActiveJob::Base.retry_jitter = 0.6

      travel_to Time.now

      RetryJob.perform_later "DefaultsError", 2, :log_scheduled_at

      assert_not_equal [
        "Raised DefaultsError for the 1st time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Successfully completed job"
      ], JobBuffer.values
    ensure
      ActiveJob::Base.retry_jitter = old_jitter
    end

    test "random wait time for polynomially retrying job when retry jitter delay multiplier value is between 1 and 2" do
      old_jitter = ActiveJob::Base.retry_jitter
      ActiveJob::Base.retry_jitter = 1.2

      travel_to Time.now

      RetryJob.perform_later "PolynomialWaitTenAttemptsError", 2, :log_scheduled_at

      assert_not_equal [
        "Raised PolynomialWaitTenAttemptsError for the 1st time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Successfully completed job"
      ], JobBuffer.values
    ensure
      ActiveJob::Base.retry_jitter = old_jitter
    end

    test "random wait time for negative jitter value" do
      old_jitter = ActiveJob::Base.retry_jitter
      ActiveJob::Base.retry_jitter = -1.2

      travel_to Time.now

      RetryJob.perform_later "PolynomialWaitTenAttemptsError", 2, :log_scheduled_at

      assert_not_equal [
        "Raised PolynomialWaitTenAttemptsError for the 1st time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Successfully completed job"
      ], JobBuffer.values
    ensure
      ActiveJob::Base.retry_jitter = old_jitter
    end

    test "retry jitter disabled with nil" do
      travel_to Time.now

      RetryJob.perform_later "DisabledJitterError", 3, :log_scheduled_at

      assert_equal [
        "Raised DisabledJitterError for the 1st time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Raised DisabledJitterError for the 2nd time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Successfully completed job"
      ], JobBuffer.values
    end

    test "retry jitter disabled with zero" do
      travel_to Time.now

      RetryJob.perform_later "ZeroJitterError", 3, :log_scheduled_at

      assert_equal [
        "Raised ZeroJitterError for the 1st time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Raised ZeroJitterError for the 2nd time",
        "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
        "Successfully completed job"
      ], JobBuffer.values
    end

    test "custom wait retrying job" do
      travel_to Time.now

      RetryJob.perform_later "CustomWaitTenAttemptsError", 5, :log_scheduled_at

      assert_equal [
        "Raised CustomWaitTenAttemptsError for the 1st time",
        "Next execution scheduled at #{(Time.now + 2.seconds).to_f}",
        "Raised CustomWaitTenAttemptsError for the 2nd time",
        "Next execution scheduled at #{(Time.now + 4.seconds).to_f}",
        "Raised CustomWaitTenAttemptsError for the 3rd time",
        "Next execution scheduled at #{(Time.now + 6.seconds).to_f}",
        "Raised CustomWaitTenAttemptsError for the 4th time",
        "Next execution scheduled at #{(Time.now + 8.seconds).to_f}",
        "Successfully completed job"
      ], JobBuffer.values
    end

    test "use individual execution timers when calculating retry delay" do
      travel_to Time.now

      exceptions_to_raise = %w(PolynomialWaitTenAttemptsError CustomWaitTenAttemptsError PolynomialWaitTenAttemptsError CustomWaitTenAttemptsError)

      random_amount = 1

      Kernel.stub(:rand, random_amount) do
        RetryJob.perform_later exceptions_to_raise, 5, :log_scheduled_at

        delay_for_jitter = -> (delay) { random_amount * delay * ActiveJob::Base.retry_jitter }

        assert_equal [
          "Raised PolynomialWaitTenAttemptsError for the 1st time",
          "Next execution scheduled at #{(Time.now + 3.seconds + delay_for_jitter.(1)).to_f}",
          "Raised CustomWaitTenAttemptsError for the 2nd time",
          "Next execution scheduled at #{(Time.now + 2.seconds).to_f}",
          "Raised PolynomialWaitTenAttemptsError for the 3rd time",
          "Next execution scheduled at #{(Time.now + 18.seconds + delay_for_jitter.(16)).to_f}",
          "Raised CustomWaitTenAttemptsError for the 4th time",
          "Next execution scheduled at #{(Time.now + 4.seconds).to_f}",
          "Successfully completed job"
        ], JobBuffer.values
      end
    end

    test "successfully retry job throwing one of two retryable exceptions" do
      RetryJob.perform_later "SecondRetryableErrorOfTwo", 3

      assert_equal [
        "Raised SecondRetryableErrorOfTwo for the 1st time",
        "Raised SecondRetryableErrorOfTwo for the 2nd time",
        "Successfully completed job" ], JobBuffer.values
    end

    test "discard job throwing one of two discardable exceptions" do
      RetryJob.perform_later "SecondDiscardableErrorOfTwo", 2
      assert_equal [ "Raised SecondDiscardableErrorOfTwo for the 1st time" ], JobBuffer.values
    end

    test "successfully retry job throwing DeserializationError" do
      RetryJob.perform_later Person.new(404), 5
      assert_equal ["Raised ActiveJob::DeserializationError for the 5 time"], JobBuffer.values
    end

    test "successfully retry job throwing UnlimitedRetryError a few times" do
      RetryJob.perform_later "UnlimitedRetryError", 10

      assert_equal 10, JobBuffer.values.size
      assert_equal "Raised UnlimitedRetryError for the 9th time", JobBuffer.values[8]
      assert_equal "Successfully completed job", JobBuffer.values[9]
    end

    test "running a job enqueued by AJ 5.2" do
      job = RetryJob.new("DefaultsError", 6)
      job.exception_executions = nil # This is how jobs from Rails 5.2 will look

      assert_raises DefaultsError do
        job.enqueue
      end

      assert_equal 5, JobBuffer.values.count
    end

    test "running a job enqueued and attempted under AJ 5.2" do
      job = RetryJob.new("DefaultsError", 6)

      # Fake 4 previous executions under AJ 5.2
      job.exception_executions = nil
      job.executions = 4

      assert_raises DefaultsError do
        job.enqueue
      end

      assert_equal ["Raised DefaultsError for the 5th time"], JobBuffer.values
    end

    test "#after_discard block is run when an unhandled error is raised" do
      assert_raises(AfterDiscardRetryJob::UnhandledError) do
        AfterDiscardRetryJob.perform_later("AfterDiscardRetryJob::UnhandledError", 2)
      end

      assert_equal "Ran after_discard for job. Message: AfterDiscardRetryJob::UnhandledError", JobBuffer.last_value
    end

    test "#after_discard block is run when #retry_on is passed a block" do
      AfterDiscardRetryJob.perform_later("AfterDiscardRetryJob::CustomCatchError", 6)

      assert_equal "Ran after_discard for job. Message: AfterDiscardRetryJob::CustomCatchError", JobBuffer.last_value
    end

    test "#after_discard block is only run once when an error class and its superclass are handled by separate #retry_on calls" do
      assert_raises(AfterDiscardRetryJob::ChildAfterDiscardError) do
        AfterDiscardRetryJob.perform_later("AfterDiscardRetryJob::ChildAfterDiscardError", 6)
      end
      assert_equal ["Raised AfterDiscardRetryJob::ChildAfterDiscardError for the 5th time", "Ran after_discard for job. Message: AfterDiscardRetryJob::ChildAfterDiscardError"], JobBuffer.values.last(2)
    end

    test "#after_discard is run when a job is discarded via #discard_on" do
      AfterDiscardRetryJob.perform_later("AfterDiscardRetryJob::DiscardableError", 2)

      assert_equal "Ran after_discard for job. Message: AfterDiscardRetryJob::DiscardableError", JobBuffer.last_value
    end

    test "#after_discard is run when a job is discarded via #discard_on with a block passed to #discard_on" do
      AfterDiscardRetryJob.perform_later("AfterDiscardRetryJob::CustomDiscardableError", 2)

      expected_array = [
        "Dealt with a job that was discarded in a custom way. Message: AfterDiscardRetryJob::CustomDiscardableError",
        "Ran after_discard for job. Message: AfterDiscardRetryJob::CustomDiscardableError"
      ]
      assert_equal expected_array, JobBuffer.values.last(2)
    end
  end
end
