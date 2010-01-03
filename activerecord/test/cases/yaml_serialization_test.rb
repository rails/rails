require "cases/helper"
require 'models/topic'

class YamlSerializationTest < ActiveRecord::TestCase
  def test_to_yaml_with_time_with_zone_should_not_raise_exception
    Time.zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]
    ActiveRecord::Base.time_zone_aware_attributes = true
    topic = Topic.new(:written_on => DateTime.now)
    assert_nothing_raised { topic.to_yaml }
  end
end
