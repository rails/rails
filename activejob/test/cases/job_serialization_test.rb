# frozen_string_literal: true

require "helper"
require "jobs/gid_job"
require "jobs/hello_job"
require "models/person"
require "json"
require "active_support/json"

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

  test "a deserialized job keeps its locale even if I18n.locale changes" do
    old_locales = I18n.available_locales
    begin
      I18n.available_locales = [:en, :es]
      I18n.locale = :es
      payload = HelloJob.new.serialize
      assert_equal "es", payload["locale"]

      I18n.locale = :en

      new_job = HelloJob.new
      new_job.deserialize(payload)

      assert_equal "es", new_job.serialize["locale"]
    ensure
      I18n.available_locales = old_locales
    end
  end

  test "keeps scheduled_at around after deserialization if data doesnt include it" do
    freeze_time

    current_time = Time.now

    job = HelloJob.new
    serialized_job = job.serialize
    job.set(wait_until: current_time)

    job.deserialize(serialized_job)

    assert_equal current_time, job.scheduled_at
  end

  test "deserializes enqueued_at when ActiveSupport.parse_json_times is true" do
    freeze_time

    Time.use_zone "US/Eastern" do
      with_parse_json_times(true) do
        current_time = Time.now

        job = HelloJob.new
        serialized_job = job.serialize
        payload = ActiveSupport::JSON.decode(serialized_job.to_json)

        new_job = HelloJob.new
        new_job.deserialize(payload)

        assert_equal current_time, new_job.enqueued_at
      end
    end
  end

  test "deserializes scheduled_at when ActiveSupport.parse_json_times is true" do
    freeze_time

    Time.use_zone "US/Eastern" do
      with_parse_json_times(true) do
        current_time = Time.now

        job = HelloJob.new
        job.scheduled_at = current_time
        serialized_job = job.serialize
        payload = ActiveSupport::JSON.decode(serialized_job.to_json)

        new_job = HelloJob.new
        new_job.deserialize(payload)

        assert_equal current_time, new_job.scheduled_at
      end
    end
  end

  test "serialize and deserialize are symmetric" do
    # Ensure `enqueued_at` does not change between serializations
    freeze_time

    # Round trip a job in memory only
    h1 = HelloJob.new("Rafael")
    h2 = HelloJob.deserialize(h1.serialize)
    assert_equal h1.serialize, h2.serialize

    # Now verify it's identical to a JSON round trip.
    # We don't want any non-native JSON elements in the job hash,
    # like symbols.
    payload = JSON.dump(h2.serialize)
    h3 = HelloJob.deserialize(JSON.load(payload))
    assert_equal h2.serialize, h3.serialize
  end

  test "deserialize raises a specific exception on unknown `job_class`" do
    payload = HelloJob.new.serialize

    # Simulate the job class being missing, for example during rolling deploys when
    # the server enqueues a new job but the job processor hasn't been restarted yet.
    payload["job_class"] = "IDontExist"
    assert_raises(ActiveJob::UnknownJobClassError) do
      HelloJob.deserialize(payload)
    end
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

  test "serialize stores provider_job_id" do
    job = HelloJob.new
    assert_nil job.serialize["provider_job_id"]

    job.provider_job_id = "some value set by adapter"
    assert_equal job.provider_job_id, job.serialize["provider_job_id"]
  end

  test "serialize stores the current timezone" do
    Time.use_zone "Hawaii" do
      job = HelloJob.new
      assert_equal "Hawaii", job.serialize["timezone"]
    end
  end

  test "serializes and deserializes enqueued_at with full precision" do
    freeze_time

    serialized = HelloJob.new.serialize
    assert_kind_of String, serialized["enqueued_at"]

    enqueued_at = HelloJob.deserialize(serialized).enqueued_at
    assert_kind_of Time, enqueued_at
    assert_equal Time.now.utc, enqueued_at
  end

  test "serializes and deserializes scheduled_at as Time" do
    freeze_time
    current_time = Time.now

    job = HelloJob.new
    job.scheduled_at = current_time
    serialized_job = job.serialize
    assert_kind_of String, serialized_job["enqueued_at"]
    assert_equal current_time.utc.iso8601(9), serialized_job["enqueued_at"]

    deserialized_job = HelloJob.new
    deserialized_job.deserialize(serialized_job)
    assert_equal current_time, deserialized_job.scheduled_at

    assert_equal job.serialize, deserialized_job.serialize
  end

  private
    def with_parse_json_times(value)
      old_value = ActiveSupport.parse_json_times
      ActiveSupport.parse_json_times = value
      yield
    ensure
      ActiveSupport.parse_json_times = old_value
    end
end
