require "helper"
require "jobs/hello_job"
require "active_support/core_ext/numeric/time"

class QueuingTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "run queued job" do
    HelloJob.perform_later
    assert_equal "David says hello", JobBuffer.last_value
  end

  test "run queued job with arguments" do
    HelloJob.perform_later "Jamie"
    assert_equal "Jamie says hello", JobBuffer.last_value
  end

  test "run queued job later" do
    begin
      result = HelloJob.set(wait_until: 1.second.ago).perform_later "Jamie"
      assert result
    rescue NotImplementedError
      skip
    end
  end

  test "job returned by enqueue has the arguments available" do
    job = HelloJob.perform_later "Jamie"
    assert_equal [ "Jamie" ], job.arguments
  end

  test "job returned by perform_at has the timestamp available" do
    begin
      job = HelloJob.set(wait_until: Time.utc(2014, 1, 1)).perform_later
      assert_equal Time.utc(2014, 1, 1).to_f, job.scheduled_at
    rescue NotImplementedError
      skip
    end
  end
end
