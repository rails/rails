require 'helper'
require 'jobs/gid_job'
require 'models/person'

class JobSerializationTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
    @person = Person.find(5)
  end

  test 'serialize job with gid' do
    GidJob.perform_later @person
    assert_equal "Person with ID: 5", JobBuffer.last_value
  end
end
