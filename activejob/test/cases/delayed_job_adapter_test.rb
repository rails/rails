# frozen_string_literal: true

require "helper"
require "jobs/disable_log_job"
require "jobs/hello_job"

return unless adapter_is?(:delayed_job)

class DelayedJobAdapterTest < ActiveSupport::TestCase
  test "does not log arguments when log_arguments is set to false on a job" do
    job_id = SecureRandom.uuid

    job_wrapper = ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(
      "job_class" => DisableLogJob.to_s,
      "queue_name" => "default",
      "job_id" => job_id,
      "arguments" => { "some" => { "job" => "arguments" } }
    )

    assert_equal "DisableLogJob [#{job_id}] from DelayedJob(default)", job_wrapper.display_name
  end

  test "logs arguments when log_arguments is set to true on a job" do
    job_id = SecureRandom.uuid
    arguments = { "some" => { "job" => "arguments" } }

    job_wrapper = ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(
      "job_class" => HelloJob.to_s,
      "queue_name" => "default",
      "job_id" => job_id,
      "arguments" => arguments
    )

    assert_equal "HelloJob [#{job_id}] from DelayedJob(default) with arguments: #{arguments}",
                 job_wrapper.display_name
  end

  test "shows name for invalid job class" do
    job_id = SecureRandom.uuid

    job_wrapper = ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(
      "job_class" => "NotExistingJob",
      "queue_name" => "default",
      "job_id" => job_id,
      "arguments" => { "some" => { "job" => "arguments" } }
    )

    assert_equal "NotExistingJob [#{job_id}] from DelayedJob(default)", job_wrapper.display_name
  end
end
