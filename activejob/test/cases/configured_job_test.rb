# frozen_string_literal: true

require "helper"
require "minitest/mock"

class ConfiguredJobTest < ActiveSupport::TestCase
  test "perform_now should create a new instance with the given args and run perform_now" do
    mock_class    = Minitest::Mock.new
    mock_instance = Minitest::Mock.new

    args = ["arg1" "arg2"]

    mock_class.expect :new, mock_instance, [args]
    mock_instance.expect :perform_now, true

    ActiveJob::ConfiguredJob.new(mock_class).perform_now(args)

    assert_mock mock_class
    assert_mock mock_instance
  end

  test "perform_later should create a new instance with the given args and run enqueue with the given options" do
    mock_class    = Minitest::Mock.new
    mock_instance = Minitest::Mock.new

    args = ["arg1" "arg2"]
    options = { op1: "op1", op2: "op2" }

    mock_class.expect :new, mock_instance, [args]
    mock_instance.expect :enqueue, true, [options]

    ActiveJob::ConfiguredJob.new(mock_class, options).perform_later(args)

    assert_mock mock_class
    assert_mock mock_instance
  end
end
