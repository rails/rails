require 'helper'
require 'active_job/arguments'
require 'models/person'
require 'active_support/core_ext/hash/indifferent_access'

class ParameterSerializationTest < ActiveSupport::TestCase
  test 'should make no change to regular values' do
    assert_equal [ 1, "something" ], ActiveJob::Arguments.serialize([ 1, "something" ])
  end

  test 'should not allow complex objects' do
    assert_equal [ nil ], ActiveJob::Arguments.serialize([ nil ])
    assert_equal [ 1 ], ActiveJob::Arguments.serialize([ 1 ])
    assert_equal [ 1.0 ], ActiveJob::Arguments.serialize([ 1.0 ])
    assert_equal [ 'a' ], ActiveJob::Arguments.serialize([ 'a' ])
    assert_equal [ true ], ActiveJob::Arguments.serialize([ true ])
    assert_equal [ false ], ActiveJob::Arguments.serialize([ false ])
    assert_equal [ { "a" => 1, "b" => 2 } ], ActiveJob::Arguments.serialize([ { a: 1, "b" => 2 } ])
    assert_equal [ [ 1 ] ], ActiveJob::Arguments.serialize([ [ 1 ] ])
    assert_equal [ 1_000_000_000_000_000_000_000 ], ActiveJob::Arguments.serialize([ 1_000_000_000_000_000_000_000 ])

    err = assert_raises RuntimeError do
      ActiveJob::Arguments.serialize([ 1, self ])
    end
    assert_equal "Unsupported argument type: #{self.class.name}", err.message
  end

  test 'should dive deep into arrays or hashes' do
    assert_equal [ { "a" => Person.find(5).gid }.with_indifferent_access ], ActiveJob::Arguments.serialize([ { a: Person.find(5) } ])
    assert_equal [ [ Person.find(5).gid ] ], ActiveJob::Arguments.serialize([ [ Person.find(5) ] ])
  end

  test 'should dive deep into arrays or hashes and raise exception on complex objects' do
    err = assert_raises RuntimeError do
      ActiveJob::Arguments.serialize([ 1, [self] ])
    end
    assert_equal "Unsupported argument type: #{self.class.name}", err.message
  end

  test 'shoud dive deep into hashes and allow raise exception on not string/symbol keys' do
    err = assert_raises RuntimeError do
      ActiveJob::Arguments.serialize([ [ { 1 => 2 } ] ])
    end
    assert_equal "Unsupported hash key type: Fixnum", err.message
  end

  test 'should serialize records with global id' do
    assert_equal [ Person.find(5).gid ], ActiveJob::Arguments.serialize([ Person.find(5) ])
  end

  test 'should serialize values and records together' do
    assert_equal [ 3, Person.find(5).gid ], ActiveJob::Arguments.serialize([ 3, Person.find(5) ])
  end
end

class ParameterDeserializationTest < ActiveSupport::TestCase
  test 'should make no change to regular values' do
    assert_equal [ 1, "something" ], ActiveJob::Arguments.deserialize([ 1, "something" ])
  end

  test 'should deserialize records with global id' do
    assert_equal [ Person.find(5) ], ActiveJob::Arguments.deserialize([ Person.find(5).gid ])
  end

  test 'should serialize values and records together' do
    assert_equal [ 3, Person.find(5) ], ActiveJob::Arguments.deserialize([ 3, Person.find(5).gid ])
  end

  test 'should dive deep when deserialising arrays' do
    assert_equal [ [ 3, Person.find(5) ] ], ActiveJob::Arguments.deserialize([ [ 3, Person.find(5).gid ] ])
  end

  test 'should dive deep when deserialising hashes' do
    assert_equal [ { "5" => Person.find(5) } ], ActiveJob::Arguments.deserialize([ { "5" => Person.find(5).gid } ])
  end

end
