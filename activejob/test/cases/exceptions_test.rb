require 'helper'
require 'jobs/retry_job'
require 'byebug'

class ExceptionsTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "successfully retry job throwing exception against defaults" do
    RetryJob.perform_later 'DefaultsError', 5

    assert_equal [
      "Raised DefaultsError for the 1st time",
      "Raised DefaultsError for the 2nd time",
      "Raised DefaultsError for the 3rd time",
      "Raised DefaultsError for the 4th time",
      "Successfully completed job" ], JobBuffer.values
  end

  test "successfully retry job throwing exception against higher limit" do
    RetryJob.perform_later 'ShortWaitTenAttemptsError', 9
    assert_equal 9, JobBuffer.values.count
  end

  test "failed retry job when exception kept occurring against defaults" do
    begin
      RetryJob.perform_later 'DefaultsError', 6
      assert_equal "Raised DefaultsError for the 5th time", JobBuffer.last_value
    rescue DefaultsError
      pass
    end
  end

  test "failed retry job when exception kept occurring against higher limit" do
    begin
      RetryJob.perform_later 'ShortWaitTenAttemptsError', 11
      assert_equal "Raised ShortWaitTenAttemptsError for the 10th time", JobBuffer.last_value
    rescue ShortWaitTenAttemptsError
      pass
    end
  end

  test "discard job" do
    RetryJob.perform_later 'DiscardableError', 2
    assert_equal "Raised DiscardableError for the 1st time", JobBuffer.last_value
  end
  
  test "custom handling of job that exceeds retry attempts" do
    RetryJob.perform_later 'CustomCatchError', 6
    assert_equal "Dealt with a job that failed to retry in a custom way", JobBuffer.last_value
  end
end

class ExponentiallyBackoffExceptionsTest < ActiveJob::TestCase
  setup do
    JobBuffer.clear
  end

  test "exponentially retrying job" do
    travel_to Time.now

    perform_enqueued_jobs do
      assert_performed_with at: (Time.now + 3.seconds).to_i do
      assert_performed_with at: (Time.now + 18.seconds).to_i do
      assert_performed_with at: (Time.now + 83.seconds).to_i do
      assert_performed_with at: (Time.now + 258.seconds).to_i do
        RetryJob.perform_later 'ExponentialWaitTenAttemptsError', 5
      end
      end
      end
      end
    end
  end

  test "custom wait retrying job" do
    travel_to Time.now

    perform_enqueued_jobs do
      assert_performed_with at: (Time.now + 2.seconds).to_i do
      assert_performed_with at: (Time.now + 4.seconds).to_i do
      assert_performed_with at: (Time.now + 6.seconds).to_i do
      assert_performed_with at: (Time.now + 8.seconds).to_i do
        RetryJob.perform_later 'CustomWaitTenAttemptsError', 5
      end
      end
      end
      end
    end
  end
end