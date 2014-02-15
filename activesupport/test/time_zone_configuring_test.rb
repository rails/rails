require 'abstract_unit'
require 'active_support/time'

class TimeZoneConfiguringTest < ActiveSupport::TestCase

  def with_custom_mapping
    old_mapping = ActiveSupport::TimeZone.mapping
    mapping = { "Mazatlan" => "America/Mazatlan",
                "Hawaii" => "Pacific/Honolulu",
                "Mexico City" => "America/Mexico_City",
                "Monterrey" => "America/Monterrey",
                "Custom name" => "America/Guatemala",
                "Curacao" => "America/Curacao"} #not in default MAPPING
    
    ActiveSupport::TimeZone.set_mapping(mapping)

    yield mapping
  ensure 
    ActiveSupport::TimeZone.set_mapping old_mapping
  end

  def test_setting_timezones
    with_custom_mapping do |mapping|
      zones = ActiveSupport::TimeZone.all
      assert_equal 6, zones.count
      zones.each do |zone|
        assert mapping.include?(zone.name)
      end
    end
  end

  def test_finding_custom_timezones
    with_custom_mapping do
      custom_named = ActiveSupport::TimeZone["Custom name"]
      not_previously_defined = ActiveSupport::TimeZone["Curacao"]
      not_defined = ActiveSupport::TimeZone["Paris"]

      assert !custom_named.nil?
      assert !not_previously_defined.nil?
      assert not_defined.nil?
      assert_equal -14400, not_previously_defined.utc_offset
    end
  end

end
