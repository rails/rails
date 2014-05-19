require 'helper'
require 'active_job/parameters'
require 'models/person'

class ParameterSerializationTest < ActiveSupport::TestCase
  test 'should make no change to regular values' do
    assert_equal [ 1, "something" ], ActiveJob::Parameters.serialize([ 1, "something" ])
  end

  test 'should not allow complex objects' do
    assert_equal [ nil ], ActiveJob::Parameters.serialize([ nil ])
    assert_equal [ 1 ], ActiveJob::Parameters.serialize([ 1 ])
    assert_equal [ 1.0 ], ActiveJob::Parameters.serialize([ 1.0 ])
    assert_equal [ 'a' ], ActiveJob::Parameters.serialize([ 'a' ])
    assert_equal [ true ], ActiveJob::Parameters.serialize([ true ])
    assert_equal [ false ], ActiveJob::Parameters.serialize([ false ])
    assert_equal [ { a: 1 } ], ActiveJob::Parameters.serialize([ { a: 1 } ])
    assert_equal [ [ 1 ] ], ActiveJob::Parameters.serialize([ [ 1 ] ])
    assert_equal [ 1_000_000_000_000_000_000_000 ], ActiveJob::Parameters.serialize([ 1_000_000_000_000_000_000_000 ])

    err = assert_raises RuntimeError do
      ActiveJob::Parameters.serialize([ 1, self ])
    end
    assert_equal "Unsupported parameter type: #{self.class.name}", err.message
  end

  test 'should serialize records with global id' do
    assert_equal [ Person.find(5).gid ], ActiveJob::Parameters.serialize([ Person.find(5) ])
  end

  test 'should serialize values and records together' do
    assert_equal [ 3, Person.find(5).gid ], ActiveJob::Parameters.serialize([ 3, Person.find(5) ])
  end
end

class ParameterDeserializationTest < ActiveSupport::TestCase
  test 'should make no change to regular values' do
    assert_equal [ 1, "something" ], ActiveJob::Parameters.deserialize([ 1, "something" ])
  end

  test 'should deserialize records with global id' do
    assert_equal [ Person.find(5) ], ActiveJob::Parameters.deserialize([ Person.find(5).gid ])
  end

  test 'should serialize values and records together' do
    assert_equal [ 3, Person.find(5) ], ActiveJob::Parameters.deserialize([ 3, Person.find(5).gid ])
  end
end
