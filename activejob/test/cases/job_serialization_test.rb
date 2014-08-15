require 'helper'
require 'jobs/gid_job'
require 'models/person'

class JobSerializationTest < ActiveSupport::TestCase
  setup do
    Thread.current[:ajbuffer] = []
    @person = Person.find(5)
  end

  test 'serialize job with gid' do
    GidJob.enqueue @person
    assert_equal "Person with ID: 5", Thread.current[:ajbuffer].pop
  end
end
