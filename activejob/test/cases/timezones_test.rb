# frozen_string_literal: true

require "helper"
require "jobs/timezone_dependent_job"

class TimezonesTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "it performs the job in the given timezone" do
    job = TimezoneDependentJob.new("2018-01-01T00:00:00Z")
    job.timezone = "London"
    job.perform_now

    assert_equal "Happy New Year!", JobBuffer.last_value

    job = TimezoneDependentJob.new("2018-01-01T00:00:00Z")
    job.timezone = "Eastern Time (US & Canada)"
    job.perform_now

    assert_equal "Just 5 hours to go", JobBuffer.last_value
  end

  test "perform_now passes down current timezone to the job" do
    Time.zone = "America/New_York"

    Time.use_zone("London") do
      job = TimezoneDependentJob.new("2018-01-01T00:00:00Z")
      assert_equal "London", job.timezone
      job.perform_now
    end

    assert_equal "Happy New Year!", JobBuffer.last_value
  ensure
    Time.zone = nil
  end
end
