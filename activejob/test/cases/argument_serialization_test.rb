require 'helper'
require 'active_job/arguments'
require 'models/person'
require 'active_support/core_ext/hash/indifferent_access'

class ArgumentSerializationTest < ActiveSupport::TestCase
  setup do
    @person = Person.find('5')
  end

  [ nil, 1, 1.0, 1_000_000_000_000_000_000_000,
    'a', true, false,
    [ 1, 'a' ],
    { 'a' => 1 }
  ].each do |arg|
    test "serializes #{arg.class} verbatim" do
      assert_arguments_unchanged arg
    end
  end

  [ :a, Object.new, self, Person.find('5').to_gid ].each do |arg|
    test "does not serialize #{arg.class}" do
      assert_raises ActiveJob::SerializationError do
        ActiveJob::Arguments.serialize [ arg ]
      end

      assert_raises ActiveJob::DeserializationError do
        ActiveJob::Arguments.deserialize [ arg ]
      end
    end
  end

  test 'should convert records to Global IDs' do
    assert_arguments_roundtrip [@person], [@person.to_gid.to_s]
  end

  test 'should dive deep into arrays and hashes' do
    assert_arguments_roundtrip [3, [@person]], [3, [@person.to_gid.to_s]]
    assert_arguments_roundtrip [{ 'a' => @person }], [{ 'a' => @person.to_gid.to_s }.with_indifferent_access]
  end

  test 'should stringify symbol hash keys' do
    assert_equal [ 'a' => 1 ], ActiveJob::Arguments.serialize([ a: 1 ])
  end

  test 'should disallow non-string/symbol hash keys' do
    assert_raises ActiveJob::SerializationError do
      ActiveJob::Arguments.serialize [ { 1 => 2 } ]
    end

    assert_raises ActiveJob::SerializationError do
      ActiveJob::Arguments.serialize [ { :a => [{ 2 => 3 }] } ]
    end
  end

  test 'should not allow non-primitive objects' do
    assert_raises ActiveJob::SerializationError do
      ActiveJob::Arguments.serialize [Object.new]
    end

    assert_raises ActiveJob::SerializationError do
      ActiveJob::Arguments.serialize [1, [Object.new]]
    end
  end

  private
    def assert_arguments_unchanged(*args)
      assert_arguments_roundtrip args, args
    end

    def assert_arguments_roundtrip(args, expected_serialized_args)
      serialized = ActiveJob::Arguments.serialize(args)
      assert_equal expected_serialized_args, serialized
      assert_equal args, ActiveJob::Arguments.deserialize(serialized)
    end
end
