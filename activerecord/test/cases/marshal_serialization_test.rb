# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"

class MarshalSerializationTest < ActiveRecord::TestCase
  fixtures :topics

  setup do
    @previous_format_version = ActiveRecord::Marshalling.format_version
  end

  teardown do
    ActiveRecord::Marshalling.format_version = @previous_format_version
  end

  def test_deserializing_rails_6_1_marshal_basic
    topic = Marshal.load(marshal_fixture("rails_6_1_topic"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
  end

  def test_deserializing_rails_6_1_marshal_with_loaded_association_cache
    topic = Marshal.load(marshal_fixture("rails_6_1_topic_associations"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
    assert_predicate topic.association(:replies), :loaded?
    assert_predicate topic.replies.first.association(:topic), :loaded?
  end

  def test_deserializing_rails_7_1_marshal_basic
    topic = Marshal.load(marshal_fixture("rails_7_1_topic"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
  end

  def test_deserializing_rails_7_1_marshal_with_loaded_association_cache
    topic = Marshal.load(marshal_fixture("rails_7_1_topic_associations"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
    assert_predicate topic.association(:replies), :loaded?
    assert_predicate topic.replies.first.association(:topic), :loaded?
    assert_same topic, topic.replies.first.topic
  end

  def test_rails_6_1_rountrip
    topic = Topic.find(1)
    topic.replies.to_a
    topic = Marshal.load(Marshal.dump(topic))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
    assert_predicate topic.association(:replies), :loaded?
  end

  def test_rails_7_1_rountrip
    ActiveRecord::Marshalling.format_version = 7.1

    topic = Topic.find(1)
    topic.replies.each(&:topic)
    assert_not_equal 0, topic.replies.size
    topic.replies.each do |reply|
      assert_same topic, reply.topic
    end

    topic.association(:open_replies)
    assert_equal true, topic.association_cached?(:open_replies)
    assert_not_predicate topic.association(:open_replies), :loaded?

    topic = Marshal.load(Marshal.dump(topic))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
    assert_predicate topic.association(:replies), :loaded?

    assert_not_predicate topic.association(:open_replies), :loaded?

    assert_not_equal 0, topic.replies.size
    topic.replies.each do |reply|
      assert_same topic, reply.topic
    end
  end

  private
    def marshal_fixture(file_name)
      File.binread(marshal_fixture_path(file_name))
    end

    def marshal_fixture_path(file_name)
      File.expand_path(
        "support/marshal_compatibility_fixtures/#{ActiveRecord::Base.lease_connection.adapter_name}/#{file_name}.dump",
        TEST_ROOT
      )
    end
end
