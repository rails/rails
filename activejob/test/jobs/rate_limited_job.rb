# frozen_string_literal: true

require_relative "../support/job_buffer"

class RateLimitedJob < ActiveJob::Base
  rate_limit to: 2, within: 1.minute, store: ActiveSupport::Cache::MemoryStore.new

  def perform(value = "default")
    JobBuffer.add(value)
  end
end

class RateLimitedByArgumentJob < ActiveJob::Base
  rate_limit to: 1, within: 1.minute, by: -> { arguments.first }, store: ActiveSupport::Cache::MemoryStore.new

  # This job is rate limited by the first argument, which is expected to be a user ID.
  # If the same user ID is used, the job will not execute again within the specified time frame.

  def perform(user_id, message = "")
    JobBuffer.add("#{user_id}: #{message}")
  end
end

class RateLimitedWithCustomHandlerJob < ActiveJob::Base
  rate_limit to: 1, within: 1.minute, with: -> { JobBuffer.add("rate_limited") }, store: ActiveSupport::Cache::MemoryStore.new

  # This job uses a custom handler that adds a message to JobBuffer when the rate limit is hit.
  # It does not perform any other action.

  def perform
    JobBuffer.add("performed")
  end
end

class MultiRateLimitedJob < ActiveJob::Base
  rate_limit to: 3, within: 1.minute, name: "per_minute", store: ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 1, within: 10.seconds, name: "burst", store: ActiveSupport::Cache::MemoryStore.new

  def perform
    JobBuffer.add("performed")
  end
end
