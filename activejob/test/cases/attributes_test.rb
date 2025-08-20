# frozen_string_literal: true

require "helper"

class AccountScopedJob < ActiveJob::Base
  attribute :account_id, required: true
  attribute :trace_id

  def perform
    JobBuffer.add({ account_id:, trace_id: })
  end
end

class SubClassedJob < AccountScopedJob
end

class AttributesTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "serializes and deserializes the defined attributes" do
    job_data = AccountScopedJob.new.set(account_id: 42, trace_id: "1337").serialize
    job = AccountScopedJob.new
    job.deserialize(job_data)

    assert_equal 42, job.account_id
    assert_equal "1337", job.trace_id
  end

  test "integrates with #set" do
    job = AccountScopedJob.new
    job.set(account_id: 42, trace_id: "1337")
    assert_equal 42, job.account_id
    assert_equal "1337", job.trace_id
  end

  test "attaches defines attributes to jobs" do
    job = AccountScopedJob.new
    job.trace_id = "1337"
    job.perform_now
    assert_equal "1337", JobBuffer.last_value[:trace_id]
  end

  test "defaults attributes to nil" do
    job = AccountScopedJob.new
    job.perform_now
    assert_nil JobBuffer.last_value[:trace_id]
  end

  test "raises if a required attribute is not set when enqueueing" do
    job = AccountScopedJob.new
    assert_raises(ArgumentError) { job.enqueue }
  end

  test "raises when defining an existing attribute" do
    assert_raises(ArgumentError) do
      Class.new(ActiveJob::Base) do
        attribute :queue_name
      end
    end
  end

  test "subclasses inherit the parent class attributes" do
    job = SubClassedJob.new
    job.set(account_id: 42, trace_id: "1337")
    assert_equal 42, job.account_id
    assert_equal "1337", job.trace_id
  end
end
