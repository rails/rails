# frozen_string_literal: true

require "helper"
require "jobs/gid_job"
require "jobs/hello_job"
require "models/person"
require "json"

class JobSerializationTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
    @person = Person.find(5)
  end

  test "serialize job with gid" do
    GidJob.perform_later @person
    assert_equal "Person with ID: 5", JobBuffer.last_value
  end

  test "serialize includes current locale" do
    assert_equal "en", HelloJob.new.serialize["locale"]
  end

  test "serialize and deserialize are symmetric" do
    # Round trip a job in memory only
    h1 = HelloJob.new
    h1.deserialize(h1.serialize)

    # Now verify it's identical to a JSON round trip.
    # We don't want any non-native JSON elements in the job hash,
    # like symbols.
    payload = JSON.dump(h1.serialize)
    h2 = HelloJob.new
    h2.deserialize(JSON.load(payload))
    assert_equal h1.serialize, h2.serialize
  end

  test "deserialize sets locale" do
    job = HelloJob.new
    job.deserialize "locale" => "es"
    assert_equal "es", job.locale
  end

  test "deserialize sets default locale" do
    job = HelloJob.new
    job.deserialize({})
    assert_equal "en", job.locale
  end

  test "serialize and deserialize job with scheduled_at" do
    current_time = Time.now.to_f

    job = HelloJob.new
    job.scheduled_at = current_time
    serialized_job = job.serialize
    assert_equal current_time, serialized_job["scheduled_at"]

    deserialized_job = HelloJob.new
    deserialized_job.deserialize(serialized_job)
    assert_equal current_time, deserialized_job.serialize["scheduled_at"]
    assert_equal job.serialize, deserialized_job.serialize
  end

  test "serialize stores provider_job_id" do
    job = HelloJob.new
    assert_nil job.serialize["provider_job_id"]

    job.provider_job_id = "some value set by adapter"
    assert_equal job.provider_job_id, job.serialize["provider_job_id"]
  end
end
