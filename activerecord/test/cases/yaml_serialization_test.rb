# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "models/post"
require "models/author"

class YamlSerializationTest < ActiveRecord::TestCase
  fixtures :topics, :authors, :author_addresses, :posts

  def test_to_yaml_with_time_with_zone_should_not_raise_exception
    with_timezone_config aware_attributes: true, zone: "Pacific Time (US & Canada)" do
      topic = Topic.new(written_on: DateTime.now)
      assert_nothing_raised { topic.to_yaml }
    end
  ensure
    Topic.reset_column_information
  end

  def test_roundtrip
    topic = Topic.first
    assert topic
    t = yaml_load YAML.dump topic
    assert_equal topic, t
  end

  def test_roundtrip_serialized_column
    topic = Topic.new(content: { "omg" => "lol" })
    assert_equal({ "omg" => "lol" }, yaml_load(YAML.dump(topic)).content)
  end

  def test_psych_roundtrip
    topic = Topic.first
    assert topic
    t = yaml_load Psych.dump topic
    assert_equal topic, t
  end

  def test_psych_roundtrip_new_object
    topic = Topic.new
    assert topic
    t = yaml_load Psych.dump topic
    assert_equal topic.attributes, t.attributes
  end

  def test_active_record_relation_serialization
    assert_nothing_raised do
      [Topic.all].to_yaml
    end
  end

  def test_raw_types_are_not_changed_on_round_trip
    topic = Topic.new(parent_id: "123")
    assert_equal "123", topic.parent_id_before_type_cast
    assert_equal "123", yaml_load(YAML.dump(topic)).parent_id_before_type_cast
  end

  def test_cast_types_are_not_changed_on_round_trip
    topic = Topic.new(parent_id: "123")
    assert_equal 123, topic.parent_id
    assert_equal 123, yaml_load(YAML.dump(topic)).parent_id
  end

  def test_new_records_remain_new_after_round_trip
    topic = Topic.new

    assert_predicate topic, :new_record?, "New record should be new"
    assert_predicate yaml_load(YAML.dump(topic)), :new_record?, "Record should be new after deserialization"

    topic.save!

    assert_not topic.new_record?, "Saved records are not new"
    assert_not yaml_load(YAML.dump(topic)).new_record?, "Saved record should not be new after deserialization"

    topic = Topic.select("title").last

    assert_not topic.new_record?, "Loaded records without ID are not new"
    assert_not yaml_load(YAML.dump(topic)).new_record?, "Record should not be new after deserialization"
  end

  def test_types_of_virtual_columns_are_not_changed_on_round_trip
    author = Author.select("authors.*, count(posts.id) as posts_count")
      .joins(:posts)
      .group("authors.id")
      .first
    dumped = yaml_load(YAML.dump(author))

    assert_equal 5, author.posts_count
    assert_equal 5, dumped.posts_count
  end

  def test_a_yaml_version_is_provided_for_future_backwards_compat
    coder = {}
    Topic.first.encode_with(coder)

    assert coder["active_record_yaml_version"]
  end

  def test_deserializing_rails_v2_yaml
    topic = yaml_load(yaml_fixture("rails_v2"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
  end

  def test_deserializing_rails_v1_mysql_yaml
    topic = yaml_load(yaml_fixture("rails_v1_mysql"))

    assert_not_predicate topic, :new_record?
    assert_equal 1, topic.id
    assert_equal "The First Topic", topic.title
    assert_equal "Have a nice day", topic.content
  end

  def test_deserializing_rails_41_yaml
    error = assert_raises(RuntimeError) do
      yaml_load(yaml_fixture("rails_4_1_no_symbol"))
    end

    assert_equal "Active Record doesn't know how to load YAML with this format.", error.message
  end

  def test_deserializing_rails_4_2_0_yaml
    error = assert_raises(RuntimeError) do
      yaml_load(yaml_fixture("rails_4_2_0"))
    end

    assert_equal "Active Record doesn't know how to load YAML with this format.", error.message
  end

  def test_yaml_encoding_keeps_mutations
    author = Author.first
    author.name = "Sean"
    dumped = yaml_load(YAML.dump(author))

    assert_equal "Sean", dumped.name
    assert_equal author.name_was, dumped.name_was
    assert_equal author.changes, dumped.changes
  end

  def test_yaml_encoding_keeps_false_values
    topic = Topic.first
    topic.approved = false
    dumped = yaml_load(YAML.dump(topic))

    assert_equal false, dumped.approved
  end

  private
    def yaml_load(payload)
      YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(payload) : YAML.load(payload)
    end

    def yaml_fixture(file_name)
      path = File.expand_path(
        "support/yaml_compatibility_fixtures/#{file_name}.yml",
        TEST_ROOT
      )
      File.read(path)
    end
end
