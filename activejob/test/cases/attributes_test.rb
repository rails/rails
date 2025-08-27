# frozen_string_literal: true

require "helper"

class AccountScopedJob < ActiveJob::Base
  attribute :account_id

  def perform
    JobBuffer.add(account_id)
  end
end

class SubClassedJob < AccountScopedJob
end

class AttributesTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "serializes and deserializes the defined attributes" do
    job_data = AccountScopedJob.new.set(account_id: 42).serialize
    job = AccountScopedJob.new
    job.deserialize(job_data)

    assert_equal 42, job.account_id
  end

  test "integrates with #set" do
    job = AccountScopedJob.new.set(account_id: 42)
    assert_equal 42, job.account_id
  end

  test "defines attribute accessors" do
    job = AccountScopedJob.new
    job.account_id = 42
    assert_equal 42, job.account_id
  end

  test "passes attributes to the job execution" do
    AccountScopedJob.set(account_id: 42).perform_now
    assert_equal 42, JobBuffer.last_value
  end

  test "defaults attributes to nil" do
    AccountScopedJob.perform_now
    assert_nil JobBuffer.last_value
  end

  test "raises when defining an existing attribute" do
    assert_raises(ArgumentError) do
      Class.new(ActiveJob::Base) do
        attribute :queue_name
      end
    end
  end

  test "subclasses inherit the parent class attributes" do
    job = SubClassedJob.new.set(account_id: 42)
    assert_equal 42, job.account_id
  end
end
