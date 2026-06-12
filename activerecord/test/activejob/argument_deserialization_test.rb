# frozen_string_literal: true

require "activejob/helper"

require "models/tag"

class ArgumentDeserializationTest < ActiveRecord::TestCase
  test "registers ActiveRecord::RecordNotFound as an Active Job record not found exception" do
    assert_includes ActiveJob::Arguments.record_not_found_exceptions, ActiveRecord::RecordNotFound
  end

  test "missing records are wrapped in a DeserializationError::RecordNotFound" do
    tag = Tag.create!(name: "gone")
    serialized = ActiveJob::Arguments.serialize([tag])
    tag.destroy!

    error = assert_raises ActiveJob::DeserializationError::RecordNotFound do
      ActiveJob::Arguments.deserialize(serialized)
    end
    assert_kind_of ActiveJob::DeserializationError, error
    assert_instance_of ActiveRecord::RecordNotFound, error.cause
  end

  test "other errors raised while locating records are wrapped in a plain DeserializationError" do
    tag = Tag.create!(name: "unreachable")
    serialized = ActiveJob::Arguments.serialize([tag])

    Tag.stub(:find, ->(_id) { raise ActiveRecord::ConnectionFailed, "connection lost" }) do
      error = assert_raises ActiveJob::DeserializationError do
        ActiveJob::Arguments.deserialize(serialized)
      end
      assert_instance_of ActiveJob::DeserializationError, error
      assert_instance_of ActiveRecord::ConnectionFailed, error.cause
    end
  end
end
