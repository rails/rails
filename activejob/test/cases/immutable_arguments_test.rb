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

  class KeywordMutationJob < ActiveJob::Base
    def perform(foo:)
      JobBuffer.add(foo.deep_dup)
      foo[:mutated] = true
      retry_job if executions < 2
    end
  end

  class NestedMutationJob < ActiveJob::Base
    def perform(messages)
      JobBuffer.add(messages.deep_dup)
      messages.each do |message|
        message[:bar_id] = message.delete(:id)
      end
      retry_job if executions < 3
    end
  end

  class StringMutationJob < ActiveJob::Base
    def perform(name)
      JobBuffer.add(name.dup)
      name << "!"
      retry_job if executions < 2
    end
  end

  class IndifferentMutationJob < ActiveJob::Base
    def perform(data)
      JobBuffer.add(data.deep_dup)
      data[:added] = true
      retry_job if executions < 2
    end
  end

  class IdClearingRecord
    include GlobalID::Identification

    attr_reader :id
    attr_accessor :name

    def initialize(id, name = "original")
      @id = id
      @name = name
    end

    def self.find(id)
      new(id)
    end

    def self.where(id:)
      Array(id).map { |value| new(value) }
    end

    # dup drops the id, as ActiveRecord::Base#dup does. immutable_arguments
    # must not call it.
    def dup
      self.class.new(nil, name)
    end
  end

  class GlobalIdJob < ActiveJob::Base
    def perform(record)
      JobBuffer.add(record.id)
      record.name = "changed"
    end
  end

  class GlobalIdRetryJob < ActiveJob::Base
    def perform(record)
      JobBuffer.add(record.id)
      record.name = "changed"
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

    test "retries preserve keyword argument hashes when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      KeywordMutationJob.perform_later(foo: { original: "value" })

      assert_equal [
        { original: "value" },
        { original: "value" }
      ], JobBuffer.values
    end

    test "retries preserve nested hash arguments when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      NestedMutationJob.perform_later([{ id: 1, foo: "bar" }, { id: 2, foo: "bar" }])

      assert_equal [
        [{ id: 1, foo: "bar" }, { id: 2, foo: "bar" }],
        [{ id: 1, foo: "bar" }, { id: 2, foo: "bar" }],
        [{ id: 1, foo: "bar" }, { id: 2, foo: "bar" }]
      ], JobBuffer.values
    end

    test "retries preserve string arguments when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      StringMutationJob.perform_later(+"hello")

      assert_equal ["hello", "hello"], JobBuffer.values
    end

    test "retries preserve indifferent access hashes when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      IndifferentMutationJob.perform_later({ name: "original" }.with_indifferent_access)

      assert_equal [
        { "name" => "original" }.with_indifferent_access,
        { "name" => "original" }.with_indifferent_access
      ], JobBuffer.values
    end

    test "global id arguments are passed through when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      record = IdClearingRecord.new("7")
      GlobalIdJob.perform_now(record)

      assert_equal ["7"], JobBuffer.values
      assert_equal "7", record.id
      assert_equal "changed", record.name
    end

    test "global id arguments keep their id across retries when immutable_arguments is enabled" do
      ActiveJob.immutable_arguments = true

      GlobalIdRetryJob.perform_later(IdClearingRecord.new("7"))

      assert_equal ["7", "7"], JobBuffer.values
    end
  end
end
