# frozen_string_literal: true

require "helper"
require "active_support/cache"
require "jobs/rate_limited_job"

class RateLimitingTest < ActiveJob::TestCase
  setup do
    @cache_store = ActiveSupport::Cache::MemoryStore.new
    ActiveJob.rate_limit_cache_store = @cache_store
  end

  teardown do
    @cache_store.clear
  end

  test "rate limit prevents job execution when limit is exceeded" do
    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 2, within: 1.minute, store: @store

      def perform
        JobBuffer.add("performed")
      end
    end

    # First two jobs should execute
    assert_nothing_raised do
      job_class.perform_now
      job_class.perform_now
    end

    assert_equal ["performed", "performed"], JobBuffer.values

    # Third job should be rate limited
    assert_raises(ActiveJob::RateLimitExceeded) do
      job_class.perform_now
    end

    assert_equal ["performed", "performed"], JobBuffer.values
  end

  test "rate limit with custom identity function" do
    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 1, within: 1.minute, by: -> { arguments.first }, store: @store

      def perform(user_id)
        JobBuffer.add("user_#{user_id}")
      end
    end

    # Same user_id should be rate limited
    assert_nothing_raised { job_class.perform_now(1) }
    assert_raises(ActiveJob::RateLimitExceeded) { job_class.perform_now(1) }

    # Different user_id should not be rate limited
    assert_nothing_raised { job_class.perform_now(2) }

    assert_equal ["user_1", "user_2"], JobBuffer.values
  end

  test "rate limit with custom handler" do
    @store = ActiveSupport::Cache::MemoryStore.new

    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 1, within: 1.minute,
                 with: -> { JobBuffer.add("rate_limited"); raise ActiveJob::RateLimitExceeded, "Custom handling" }, store: @store

      def perform
        JobBuffer.add("performed")
      end
    end

    job_class.perform_now

    # Second call should trigger the custom handler and raise
    assert_raises(ActiveJob::RateLimitExceeded) { job_class.perform_now }

    assert_equal ["performed", "rate_limited"], JobBuffer.values
  end

  test "rate limit respects time window" do
    @store = ActiveSupport::Cache::MemoryStore.new

    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 1, within: 1.second, store: @store

      def perform
        JobBuffer.add("performed")
      end
    end

    assert_nothing_raised { job_class.perform_now }
    assert_raises(ActiveJob::RateLimitExceeded) { job_class.perform_now }

    # Wait for window to expire
    sleep 1.1

    assert_nothing_raised { job_class.perform_now }

    assert_equal ["performed", "performed"], JobBuffer.values
  end

  test "multiple rate limits with names" do
    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 10, within: 1.minute, name: "per-minute", store: @store
      rate_limit to: 1, within: 2.seconds, name: "burst", store: @store

      def perform
        JobBuffer.add("performed")
      end
    end

    # First job should pass both limits
    assert_nothing_raised { job_class.perform_now }

    # Second job should fail burst limit
    assert_raises(ActiveJob::RateLimitExceeded) { job_class.perform_now }

    # Third job immediately should also fail burst limit
    assert_raises(ActiveJob::RateLimitExceeded) { job_class.perform_now }

    assert_equal ["performed"], JobBuffer.values

    # Wait for burst window to expire
    sleep 3

    # Now should pass burst but count against per-minute
    assert_nothing_raised { job_class.perform_now }

    assert_equal ["performed", "performed"], JobBuffer.values
  end

  test "rate limit with global cache store configuration" do
    original_store = ActiveJob.rate_limit_cache_store
    store = ActiveSupport::Cache::MemoryStore.new
    ActiveJob.rate_limit_cache_store = store

    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 1, within: 1.minute

      def perform
        JobBuffer.add("performed")
      end
    end

    assert_nothing_raised { job_class.perform_now }
    assert_equal ["performed"], JobBuffer.values

    assert_raises(ActiveJob::RateLimitExceeded) { job_class.perform_now }
    assert_equal ["performed"], JobBuffer.values
  ensure
    ActiveJob.rate_limit_cache_store = original_store
  end

  test "predefined rate limited job" do
    RateLimitedJob.perform_now("first")
    RateLimitedJob.perform_now("second")

    assert_raises(ActiveJob::RateLimitExceeded) do
      RateLimitedJob.perform_now("third")
    end

    assert_equal ["first", "second"], JobBuffer.values
  end

  test "rate limited by argument job" do
    RateLimitedByArgumentJob.perform_now(1, "first")

    assert_raises(ActiveJob::RateLimitExceeded) do
      RateLimitedByArgumentJob.perform_now(1, "second")
    end

    # Different user_id should work
    RateLimitedByArgumentJob.perform_now(2, "first")

    assert_equal ["1: first", "2: first"], JobBuffer.values
  end

  test "rate limit instrumentation" do
    events = []

    job_class = Class.new(ActiveJob::Base) do
      rate_limit to: 1, within: 1.minute, store: @store

      def perform
        JobBuffer.add("performed")
      end
    end

    ActiveSupport::Notifications.subscribe("rate_limit.active_job") do |event|
      events << event
    end

    job_class.perform_now

    assert_raises(ActiveJob::RateLimitExceeded) do
      job_class.perform_now
    end

    assert_equal 1, events.size
  ensure
    ActiveSupport::Notifications.unsubscribe("rate_limit.active_job")
  end
end
