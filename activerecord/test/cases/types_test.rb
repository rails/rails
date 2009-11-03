require "cases/helper"
require 'models/topic'

class TypesTest < ActiveRecord::TestCase

  test "attribute types from columns" do
    begin
    ActiveRecord::Base.time_zone_aware_attributes = true
    attribute_type_classes = {}
    Topic.attribute_types.each { |key, type| attribute_type_classes[key] = type.class }

    expected = { "id"            => ActiveRecord::Type::Number,
                  "replies_count" => ActiveRecord::Type::Number,
                  "parent_id"     => ActiveRecord::Type::Number,
                  "content"       => ActiveRecord::Type::Serialize,
                  "written_on"    => ActiveRecord::Type::TimeWithZone,
                  "title"         => ActiveRecord::Type::Object,
                  "author_name"   => ActiveRecord::Type::Object,
                  "approved"      => ActiveRecord::Type::Object,
                  "parent_title"  => ActiveRecord::Type::Object,
                  "bonus_time"    => ActiveRecord::Type::Object,
                  "type"          => ActiveRecord::Type::Object,
                  "last_read"     => ActiveRecord::Type::Object,
                  "author_email_address" => ActiveRecord::Type::Object }

    assert_equal expected, attribute_type_classes
   ensure
     ActiveRecord::Base.time_zone_aware_attributes = false
   end
  end

end
