require "cases/helper"

class LegacyConfigTest < ActiveRecord::TestCase
  def test_one_level_config
    raw_config = {'adapter' => 'sqlite3', 'database' => 'db/foo.sqlite3'}
    config = ActiveRecord::ConnectionAdapters::ConnectionSpecification::LegacyConfigTransformer.new(raw_config).to_hash
    assert_equal ['primary'], config.keys, "should add teh primary key"
    assert_equal raw_config, config['primary']
  end

  def test_two_level_config_with_default_specification_name
    raw_config = {'primary' => {'adapter' => 'sqlite3', 'database' => 'db/foo.sqlite3'}}
    config = ActiveRecord::ConnectionAdapters::ConnectionSpecification::LegacyConfigTransformer.new(raw_config).to_hash
    assert_equal raw_config, config, "should not change the config"
  end

  def test_two_level_config_when_not_default_specification_name
    raw_config = {'secondary' => {'adapter' => 'sqlite3', 'database' => 'db/foo.sqlite3'}}
    config = ActiveRecord::ConnectionAdapters::ConnectionSpecification::LegacyConfigTransformer.new(raw_config).to_hash
    assert_equal raw_config, config, "should not change the config"
  end
end
