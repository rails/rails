require 'cases/helper'
require 'models/topic'
require 'models/reply'
require 'models/post'
require 'models/author'

class YamlSerializationTest < ActiveRecord::TestCase
  fixtures :topics, :authors, :posts

  def test_to_yaml_with_time_with_zone_should_not_raise_exception
    with_timezone_config aware_attributes: true, zone: "Pacific Time (US & Canada)" do
      topic = Topic.new(:written_on => DateTime.now)
      assert_nothing_raised { topic.to_yaml }
    end
  end

  def test_roundtrip
    topic = Topic.first
    assert topic
    t = YAML.load YAML.dump topic
    assert_equal topic, t
  end

  def test_roundtrip_serialized_column
    topic = Topic.new(:content => {:omg=>:lol})
    assert_equal({:omg=>:lol}, YAML.load(YAML.dump(topic)).content)
  end

  def test_psych_roundtrip
    topic = Topic.first
    assert topic
    t = Psych.load Psych.dump topic
    assert_equal topic, t
  end

  def test_psych_roundtrip_new_object
    topic = Topic.new
    assert topic
    t = Psych.load Psych.dump topic
    assert_equal topic.attributes, t.attributes
  end

  def test_active_record_relation_serialization
    [Topic.all].to_yaml
  end

  def test_raw_types_are_not_changed_on_round_trip
    topic = Topic.new(parent_id: "123")
    assert_equal "123", topic.parent_id_before_type_cast
    assert_equal "123", YAML.load(YAML.dump(topic)).parent_id_before_type_cast
  end

  def test_cast_types_are_not_changed_on_round_trip
    topic = Topic.new(parent_id: "123")
    assert_equal 123, topic.parent_id
    assert_equal 123, YAML.load(YAML.dump(topic)).parent_id
  end

  def test_new_records_remain_new_after_round_trip
    topic = Topic.new

    assert topic.new_record?, "Sanity check that new records are new"
    assert YAML.load(YAML.dump(topic)).new_record?, "Record should be new after deserialization"

    topic.save!

    assert_not topic.new_record?, "Saved records are not new"
    assert_not YAML.load(YAML.dump(topic)).new_record?, "Saved record should not be new after deserialization"

    topic = Topic.select('title').last

    assert_not topic.new_record?, "Loaded records without ID are not new"
    assert_not YAML.load(YAML.dump(topic)).new_record?, "Record should not be new after deserialization"
  end

  def test_types_of_virtual_columns_are_not_changed_on_round_trip
    author = Author.select('authors.*, count(posts.id) as posts_count')
      .joins(:posts)
      .group('authors.id')
      .first
    dumped = YAML.load(YAML.dump(author))

    assert_equal 5, author.posts_count
    assert_equal 5, dumped.posts_count
  end
end
