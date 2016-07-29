require 'helper'
require 'jobs/retry_job'

class ExceptionsTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "successfully retry job throwing exception against defaults" do
    RetryJob.perform_later 'SeriousError', 5

    assert_equal [
      "Raised SeriousError for the 1st time",
      "Raised SeriousError for the 2nd time",
      "Raised SeriousError for the 3rd time",
      "Raised SeriousError for the 4th time",
      "Successfully completed job" ], JobBuffer.values
  end

  test "successfully retry job throwing exception against higher limit" do
    RetryJob.perform_later 'VerySeriousError', 9
    assert_equal 9, JobBuffer.values.count
  end

  test "failed retry job when exception kept occurring against defaults" do
    begin
      RetryJob.perform_later 'SeriousError', 6
      assert_equal "Raised SeriousError for the 5th time", JobBuffer.last_value
    rescue SeriousError
      pass
    end
  end

  test "failed retry job when exception kept occurring against higher limit" do
    begin
      RetryJob.perform_later 'VerySeriousError', 11
      assert_equal "Raised VerySeriousError for the 10th time", JobBuffer.last_value
    rescue VerySeriousError
      pass
    end
  end

  test "discard job" do
    RetryJob.perform_later 'NotSeriousError', 2
    assert_equal "Raised NotSeriousError for the 1st time", JobBuffer.last_value
  end
end
