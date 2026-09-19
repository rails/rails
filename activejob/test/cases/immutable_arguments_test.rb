# frozen_string_literal: true

require "helper"

class ImmutableArgumentsTest < ActiveSupport::TestCase
  class MutatingRetryJob < ActiveJob::Base
    def perform(data)
      JobBuffer.add(data.deep_dup)
      data[:mutated] = true
      retry_job if executions < 3
    end
  end

  class ArgumentsMutationRetryJob < ActiveJob::Base
    def perform(data)
      JobBuffer.add(data.deep_dup)
      data[:from_perform] = true
      arguments[0][:from_arguments] = true
      retry_job if executions < 2
    end
  end

  setup do
    @original_immutable_arguments = ActiveJob.immutable_arguments
  end

  teardown do
    ActiveJob.immutable_arguments = @original_immutable_arguments
  end

  test "immutable_arguments defaults to false" do
    assert_equal false, ActiveJob.immutable_arguments
  end

  if adapter_is?(:inline, :test)
    test "retries reuse mutated arguments when immutable_arguments is disabled" do
      ActiveJob.immutable_arguments = false

      MutatingRetryJob.perform_later({ original: "value" })

      assert_equal [
        { original: "value" },
        { original: "value", mutated: true },
        { original: "value", mutated: true }
      ], JobBuffer.values
    end

    test "retries preserve original arguments when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      MutatingRetryJob.perform_later({ original: "value" })

      assert_equal [
        { original: "value" },
        { original: "value" },
        { original: "value" }
      ], JobBuffer.values
    end

    test "mutating self.arguments still affects retries when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      ArgumentsMutationRetryJob.perform_later({ foo: "bar" })

      assert_equal [
        { foo: "bar" },
        { foo: "bar", from_arguments: true }
      ], JobBuffer.values
      assert JobBuffer.values.none? { |value| value.key?(:from_perform) }
    end
  end
end
