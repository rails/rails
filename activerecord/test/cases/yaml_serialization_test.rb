require 'cases/helper'
require 'models/topic'

class YamlSerializationTest < ActiveRecord::TestCase
  fixtures :topics

  def test_to_yaml_with_time_with_zone_should_not_raise_exception
    tz = Time.zone
    Time.zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
    ActiveRecord::Base.time_zone_aware_attributes = true

    topic = Topic.new(:written_on => DateTime.now)
    assert_nothing_raised { topic.to_yaml }

  ensure
    Time.zone = tz
    ActiveRecord::Base.time_zone_aware_attributes = false
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

  def test_encode_with_coder
    topic = Topic.first
    coder = {}
    topic.encode_with coder
    assert_equal({'attributes' => topic.attributes}, coder)
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
end
