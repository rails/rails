require "cases/helper"
require 'models/topic'

class YamlSerializationTest < ActiveRecord::TestCase
  fixtures :topics

  def test_to_yaml_with_time_with_zone_should_not_raise_exception
    Time.zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
    ActiveRecord::Base.time_zone_aware_attributes = true
    topic = Topic.new(:written_on => DateTime.now)
    assert_nothing_raised { topic.to_yaml }
  end

  def test_roundtrip
    topic = Topic.order(:id).first
    assert topic
    t = YAML.load YAML.dump topic
    assert_equal topic, t
  end

  def test_roundtrip_serialized_column
    topic = Topic.new(:content => {:omg=>:lol})
    assert_equal({:omg=>:lol}, YAML.load(YAML.dump(topic)).content)
  end

  def test_encode_with_coder
    topic = Topic.order(:id).first
    coder = {}
    topic.encode_with coder
    assert_equal({'attributes' => topic.attributes}, coder)
  end

  begin
    require 'psych'

    def test_psych_roundtrip
      topic = Topic.order(:id).first
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
  rescue LoadError
  end
end
