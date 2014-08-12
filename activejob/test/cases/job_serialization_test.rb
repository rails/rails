require 'helper'
require 'jobs/gid_job'
require 'models/person'

class JobSerializationTest < ActiveSupport::TestCase
  setup do
    $BUFFER = []
    @person = Person.find(5)
  end

  test 'serialize job with gid' do
    GidJob.enqueue @person
    assert_equal "Person with ID: 5", $BUFFER.pop
  end
end
