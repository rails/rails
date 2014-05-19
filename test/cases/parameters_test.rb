require 'helper'
require 'active_job/parameters'
require 'models/person'

class ParameterSerializationTest < ActiveSupport::TestCase
  test 'should make no change to regular values' do
    assert_equal [ 1, "something" ], ActiveJob::Parameters.serialize([ 1, "something" ])
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
