# frozen_string_literal: true

require "helper"
require "active_job/serializers"

class SerializersTest < ActiveSupport::TestCase
  class DummyValueObject
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def ==(other)
      self.value == other.value
    end
  end

  class DummySerializer < ActiveJob::Serializers::ObjectSerializer
    def serialize(object)
      super({ "value" => object.value })
    end

    def deserialize(hash)
      DummyValueObject.new(hash["value"])
    end

    def klass
      DummyValueObject
    end
  end

  class TestSerializerWithoutKlass < ActiveJob::Serializers::ObjectSerializer; end

  setup do
    @value_object = DummyValueObject.new 123
    @original_serializers = ActiveJob::Serializers.serializers
  end

  teardown do
    ActiveJob::Serializers.serializers = @original_serializers
  end

  test "can't serialize unknown object" do
    assert_raises ActiveJob::SerializationError do
      ActiveJob::Serializers.serialize @value_object
    end
  end

  test "will serialize objects with serializers registered" do
    ActiveJob::Serializers.add_serializers DummySerializer

    assert_equal(
      { "_aj_serialized" => "SerializersTest::DummySerializer", "value" => 123 },
      ActiveJob::Serializers.serialize(@value_object)
    )
  end

  test "won't deserialize unknown hash" do
    hash = { "_dummy_serializer" => 123, "_aj_symbol_keys" => [] }
    error = assert_raises(ArgumentError) do
      ActiveJob::Serializers.deserialize(hash)
    end
    assert_equal(
      "Serializer name is not present in the argument: #{{ "_dummy_serializer" => 123, "_aj_symbol_keys" => [] }}",
      error.message
    )
  end

  test "won't deserialize unknown serializer" do
    hash = { "_aj_serialized" => "DoNotExist", "value" => 123 }
    error = assert_raises(ArgumentError) do
      ActiveJob::Serializers.deserialize(hash)
    end
    assert_equal(
      "Serializer DoNotExist is not known",
      error.message
    )
  end

  test "will deserialize known serialized objects" do
    ActiveJob::Serializers.add_serializers DummySerializer
    hash = { "_aj_serialized" => "SerializersTest::DummySerializer", "value" => 123 }
    assert_equal DummyValueObject.new(123), ActiveJob::Serializers.deserialize(hash)
  end

  test "adds new serializer" do
    ActiveJob::Serializers.add_serializers DummySerializer
    assert ActiveJob::Serializers.serializers.include?(DummySerializer.instance)
  end

  test "can't add serializer with the same key twice" do
    ActiveJob::Serializers.add_serializers DummySerializer
    assert_no_difference(-> { ActiveJob::Serializers.serializers.size }) do
      ActiveJob::Serializers.add_serializers DummySerializer
    end
  end

  test "raises a deprecation warning if the klass method doesn't exist" do
    expected_message = "TestSerializerWithoutKlass should implement a public #klass method. This will raise an error in Rails 8.2"

    assert_deprecated(expected_message, ActiveJob.deprecator) do
      ActiveJob::Serializers.add_serializers TestSerializerWithoutKlass
    end
  end
end
