# frozen_string_literal: true

require "helper"
require "active_job/serializers"
require "active_support/core_ext/object/with"
require "active_support/testing/ractors_assertions"

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

  test "resets serializers when directly setting" do
    class DummySerializerAlt < DummySerializer
      def klass; DummySerializer end
    end
    ActiveJob::Serializers.add_serializers DummySerializer
    ActiveJob::Serializers.serializers = [DummySerializerAlt]
    assert ActiveJob::Serializers.serializers.include?(DummySerializerAlt.instance)
    assert_not ActiveJob::Serializers.serializers.include?(DummySerializer.instance)
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

  class RactorTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include ActiveSupport::Testing::RactorsAssertions

    class LockingSerializer < DummySerializer
      def initialize
        super
        @lock = Mutex.new
      end
    end

    test "serializers are usable from a non-main Ractor once shareable" do
      ActiveJob::Serializers.add_serializers DummySerializer
      ActiveSupport::Ractors.with(unshareable_proc_action: :raise) { ActiveJob::Serializers.make_shareable! }

      assert_ractor_shareable ActiveJob::Serializers.serializers
      serialized = on_ractor { ActiveJob::Serializers.serialize(DummyValueObject.new(123)) }
      assert_equal({ "_aj_serialized" => "SerializersTest::DummySerializer", "value" => 123 }, serialized)
      assert_equal DummyValueObject.new(123), on_ractor(serialized) { |hash| ActiveJob::Serializers.deserialize(hash) }
      error_class = on_ractor do
        ActiveJob::Serializers.serialize(Object.new)
      rescue => error
        error.class
      end
      assert_equal ActiveJob::SerializationError, error_class
    end

    test "make_shareable! includes the serializers added by the active_job_arguments load hooks" do
      ActiveSupport.on_load(:active_job_arguments) { ActiveJob::Serializers.add_serializers DummySerializer }

      ActiveSupport::Ractors.with(unshareable_proc_action: :raise) { ActiveJob::Serializers.make_shareable! }

      assert_includes ActiveJob::Serializers.serializers, DummySerializer.instance
      assert_ractor_shareable DummySerializer.instance
    end

    test "make_shareable! doesn't make the serializers shareable when unshareable_proc_action is nil" do
      ActiveSupport::Ractors.with(unshareable_proc_action: nil) { ActiveJob::Serializers.make_shareable! }

      assert_not_predicate ActiveJob::Serializers.serializers, :frozen?
    end

    if RUBY_VERSION >= "4.0"
      test "make_shareable! raises for a serializer that can't be made shareable" do
        ActiveJob::Serializers.add_serializers LockingSerializer

        assert_raises(Ractor::Error) do
          ActiveSupport::Ractors.with(unshareable_proc_action: :raise) { ActiveJob::Serializers.make_shareable! }
        end
      end
    end
  end
end
