require 'helper'
require 'jobs/gid_job'
require 'jobs/hello_job'
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

  test 'serialize includes current locale' do
    assert_equal 'en', HelloJob.new.serialize['locale']
  end

  test 'deserialize sets locale' do
    job = HelloJob.new
    job.deserialize 'locale' => 'es'
    assert_equal 'es', job.locale
  end

  test 'deserialize sets default locale' do
    job = HelloJob.new
    job.deserialize({})
    assert_equal :en, job.locale
  end
end
