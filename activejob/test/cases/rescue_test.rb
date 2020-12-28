# frozen_string_literal: true

require "helper"
require "jobs/rescue_job"
require "models/person"

class RescueTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "rescue perform exception with retry" do
    job = RescueJob.new("david")
    job.perform_now
    assert_equal [ "rescued from ArgumentError", "performed beautifully", "Retried job DIFFERENT!" ], JobBuffer.values
  end

  test "let through unhandled perform exception" do
    job = RescueJob.new("other")
    assert_raises(RescueJob::OtherError) do
      job.perform_now
    end
  end

  test "rescue from deserialization errors" do
    RescueJob.perform_later Person.new(404)
    assert_includes JobBuffer.values, "rescued from DeserializationError"
    assert_includes JobBuffer.values, "DeserializationError original exception was Person::RecordNotFound"
    assert_not_includes JobBuffer.values, "performed beautifully"
  end

  test "should not wrap DeserializationError in DeserializationError" do
    RescueJob.perform_later [Person.new(404)]
    assert_includes JobBuffer.values, "DeserializationError original exception was Person::RecordNotFound"
  end
end
