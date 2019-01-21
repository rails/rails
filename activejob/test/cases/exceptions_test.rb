# frozen_string_literal: true

require "helper"
require "jobs/retry_job"
require "models/person"

class ExceptionsTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
    skip if adapter_skips_scheduling?(ActiveJob::Base.queue_adapter)
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

      assert_equal [
        "Raised FirstRetryableErrorOfTwo for the 1st time",
        "Raised FirstRetryableErrorOfTwo for the 2nd time",
        "Raised FirstRetryableErrorOfTwo for the 3rd time",
        "Raised SecondRetryableErrorOfTwo for the 4th time",
        "Raised SecondRetryableErrorOfTwo for the 5th time",
      ], JobBuffer.values
    end
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

    RetryJob.perform_later "LongWaitError", 2, :log_scheduled_at

    assert_equal [
      "Raised LongWaitError for the 1st time",
      "Next execution scheduled at #{(Time.now + 3600.seconds).to_f}",
      "Successfully completed job"
    ], JobBuffer.values
  end

  test "exponentially retrying job" do
    travel_to Time.now

    RetryJob.perform_later "ExponentialWaitTenAttemptsError", 5, :log_scheduled_at

    assert_equal [
      "Raised ExponentialWaitTenAttemptsError for the 1st time",
      "Next execution scheduled at #{(Time.now + 3.seconds).to_f}",
      "Raised ExponentialWaitTenAttemptsError for the 2nd time",
      "Next execution scheduled at #{(Time.now + 18.seconds).to_f}",
      "Raised ExponentialWaitTenAttemptsError for the 3rd time",
      "Next execution scheduled at #{(Time.now + 83.seconds).to_f}",
      "Raised ExponentialWaitTenAttemptsError for the 4th time",
      "Next execution scheduled at #{(Time.now + 258.seconds).to_f}",
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

  private
    def adapter_skips_scheduling?(queue_adapter)
      [
        ActiveJob::QueueAdapters::InlineAdapter,
        ActiveJob::QueueAdapters::AsyncAdapter,
        ActiveJob::QueueAdapters::SneakersAdapter
      ].include?(queue_adapter.class)
    end
end
