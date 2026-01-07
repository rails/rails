# frozen_string_literal: true

require "cases/helper"

class PostgreSQLTypeMappingRegistrationTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @adapter_class = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    @adapter_class.clear_type_mapping_callbacks!
  end

  def teardown
    @adapter_class.clear_type_mapping_callbacks!
  end

  def test_register_type_mapping_with_block
    called = false
    @adapter_class.register_type_mapping do |type_map|
      called = true
      assert_kind_of ActiveRecord::Type::HashLookupTypeMap, type_map
    end

    ActiveRecord::Base.lease_connection.reload_type_map
    assert called
  end

  def test_register_requires_block
    assert_raises(ArgumentError) { @adapter_class.register_type_mapping }
  end

  def test_custom_type_is_registered
    @adapter_class.register_type_mapping do |type_map|
      type_map.register_type("test_custom") { ActiveRecord::Type::String.new }
    end

    ActiveRecord::Base.lease_connection.reload_type_map
    type_map = ActiveRecord::Base.lease_connection.send(:type_map)
    assert type_map.key?("test_custom")
  end
end
