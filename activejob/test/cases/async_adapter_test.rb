# frozen_string_literal: true

require "helper"
require "active_job/queue_adapters/async_adapter"
require "jobs/hello_job"

class AsyncAdapterTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
    ActiveJob::Base.queue_adapter.immediate = true
  end

  test "in immediate run, perform_later runs immediately" do
    HelloJob.perform_later "Alex"
    assert_match(/Alex/, JobBuffer.last_value)
  end

  test "in immediate run, enqueue with wait: runs immediately" do
    HelloJob.set(wait_until: Date.tomorrow.noon).perform_later "Alex"
    assert_match(/Alex/, JobBuffer.last_value)
  end
end
