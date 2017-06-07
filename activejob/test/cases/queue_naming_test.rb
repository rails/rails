require "helper"
require "jobs/hello_job"
require "jobs/logging_job"
require "jobs/nested_job"

class QueueNamingTest < ActiveSupport::TestCase
  test "name derived from base" do
    assert_equal "default", HelloJob.queue_name
  end

  test "uses given queue name job" do
    original_queue_name = HelloJob.queue_name

    begin
      HelloJob.queue_as :greetings
      assert_equal "greetings", HelloJob.new.queue_name
    ensure
      HelloJob.queue_name = original_queue_name
    end
  end

  test "allows a blank queue name" do
    original_queue_name = HelloJob.queue_name

    begin
      HelloJob.queue_as ""
      assert_equal "", HelloJob.new.queue_name
    ensure
      HelloJob.queue_name = original_queue_name
    end
  end

  test "does not use a nil queue name" do
    original_queue_name = HelloJob.queue_name

    begin
      HelloJob.queue_as nil
      assert_equal "default", HelloJob.new.queue_name
    ensure
      HelloJob.queue_name = original_queue_name
    end
  end

  test "evals block given to queue_as to determine queue" do
    original_queue_name = HelloJob.queue_name

    begin
      HelloJob.queue_as { :another }
      assert_equal "another", HelloJob.new.queue_name
    ensure
      HelloJob.queue_name = original_queue_name
    end
  end

  test "can use arguments to determine queue_name in queue_as block" do
    original_queue_name = HelloJob.queue_name

    begin
      HelloJob.queue_as { arguments.first == "1" ? :one : :two }
      assert_equal "one", HelloJob.new("1").queue_name
      assert_equal "two", HelloJob.new("3").queue_name
    ensure
      HelloJob.queue_name = original_queue_name
    end
  end

  test "queue_name_prefix prepended to the queue name with default delimiter" do
    original_queue_name_prefix = ActiveJob::Base.queue_name_prefix
    original_queue_name = HelloJob.queue_name

    begin
      ActiveJob::Base.queue_name_prefix = "aj"
      HelloJob.queue_as :low
      assert_equal "aj_low", HelloJob.queue_name
    ensure
      ActiveJob::Base.queue_name_prefix = original_queue_name_prefix
      HelloJob.queue_name = original_queue_name
    end
  end

  test "queue_name_prefix prepended to the queue name with custom delimiter" do
    original_queue_name_prefix = ActiveJob::Base.queue_name_prefix
    original_queue_name_delimiter = ActiveJob::Base.queue_name_delimiter
    original_queue_name = HelloJob.queue_name

    begin
      ActiveJob::Base.queue_name_delimiter = "."
      ActiveJob::Base.queue_name_prefix = "aj"
      HelloJob.queue_as :low
      assert_equal "aj.low", HelloJob.queue_name
    ensure
      ActiveJob::Base.queue_name_prefix = original_queue_name_prefix
      ActiveJob::Base.queue_name_delimiter = original_queue_name_delimiter
      HelloJob.queue_name = original_queue_name
    end
  end

  test "uses queue passed to #set" do
    job = HelloJob.set(queue: :some_queue).perform_later
    assert_equal "some_queue", job.queue_name
  end
end
