# frozen_string_literal: true

require "helper"
require "jobs/configuration_job"
require "jobs/hello_job"

class QueuePriorityTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "priority unset by default" do
    assert_nil HelloJob.priority
  end

  test "uses given priority" do
    original_priority = HelloJob.priority

    begin
      HelloJob.queue_with_priority 90
      assert_equal 90, HelloJob.new.priority
    ensure
      HelloJob.priority = original_priority
    end
  end

  test "evals block given to priority to determine priority" do
    original_priority = HelloJob.priority

    begin
      HelloJob.queue_with_priority { 25 }
      assert_equal 25, HelloJob.new.priority
    ensure
      HelloJob.priority = original_priority
    end
  end

  test "can use arguments to determine priority in priority block" do
    original_priority = HelloJob.priority

    begin
      HelloJob.queue_with_priority { arguments.first == "1" ? 99 : 11 }
      assert_equal 99, HelloJob.new("1").priority
      assert_equal 11, HelloJob.new("3").priority
    ensure
      HelloJob.priority = original_priority
    end
  end

  test "is assigned when perform_now" do
    ConfigurationJob.set(priority: 123).perform_now
    job = JobBuffer.last_value
    assert_equal 123, job.priority
  end

  test "is assigned when perform_later" do
    ConfigurationJob.set(priority: 123).perform_later
    job = JobBuffer.last_value
    assert_equal 123, job.priority
  end
end
