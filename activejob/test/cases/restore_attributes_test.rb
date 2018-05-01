# frozen_string_literal: true

require "helper"
require "jobs/hello_job"
require "models/person"
require "json"

class RestoreAttributesTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  class ExampleStorage
    mattr_accessor :attributes
  end

  class AnotherExampleStorage
    mattr_accessor :attributes
  end

  class TestCurrent < ActiveSupport::CurrentAttributes
    attribute :person
  end

  test "restore_attributes_on saves attributes data from a given class" do
    shared_attributes = { person: Person.new(27110), to_be_teased: "Takagi-san" }
    ExampleStorage.attributes = shared_attributes
    HelloJob.restore_attributes_on ExampleStorage

    job_data = HelloJob.new.serialize
    expected = ActiveJob::Arguments.serialize(
      "restore_attributes_test/example_storage" => shared_attributes
    )

    assert_equal expected, job_data["shared_attributes"]
  end

  test "restore_attributes_on restores data back to a given class" do
    shared_attributes = { person: Person.new(27110), to_be_teased: "Takagi-san" }
    ExampleStorage.attributes = shared_attributes
    HelloJob.restore_attributes_on ExampleStorage

    # Serialize data and reset the attributes storage
    job_data = HelloJob.new.serialize
    ExampleStorage.attributes = {}

    # Deserialize data and test that that the storage class get re-set.
    HelloJob.new.deserialize(job_data)

    assert_equal shared_attributes, ExampleStorage.attributes
  end

  test "restore_attributes_on works with ActiveSupport::CurrentAttributes" do
    TestCurrent.person = Person.new(27110)
    HelloJob.restore_attributes_on TestCurrent

    job_data = HelloJob.new.serialize
    TestCurrent.person = nil

    assert_nil TestCurrent.person

    HelloJob.new.deserialize(job_data)
    assert_equal Person.new(27110), TestCurrent.person
  end

  test "restore_attributes_on supports multiple classes" do
    HelloJob.restore_attributes_on ExampleStorage, AnotherExampleStorage

    job_data = HelloJob.new.serialize
    expected = [
      "restore_attributes_test/example_storage",
      "restore_attributes_test/another_example_storage"
    ]

    assert_equal expected, job_data["shared_attributes"].map(&:first)
  end
end
