# frozen_string_literal: true

require "cases/helper"

class TypeTest < ActiveRecord::TestCase
  setup do
    @old_registry = ActiveRecord::Type.registry
    ActiveRecord::Type.registry = ActiveRecord::Type::AdapterSpecificRegistry.new
  end

  teardown do
    ActiveRecord::Type.registry = @old_registry
  end

  test "registering a new type" do
    type = Struct.new(:args)
    ActiveRecord::Type.register(:foo, type)

    assert_equal type.new(:arg), ActiveRecord::Type.lookup(:foo, :arg)
  end

  test "looking up a type for a specific adapter" do
    type = Struct.new(:args)
    pgtype = Struct.new(:args)
    ActiveRecord::Type.register(:foo, type, override: false)
    ActiveRecord::Type.register(:foo, pgtype, adapter: :postgresql)

    assert_equal type.new, ActiveRecord::Type.lookup(:foo, adapter: :sqlite)
    assert_equal pgtype.new, ActiveRecord::Type.lookup(:foo, adapter: :postgresql)
  end

  test "lookup defaults to the current adapter" do
    current_adapter = ActiveRecord::Type.adapter_name_from(ActiveRecord::Base)
    type = Struct.new(:args)
    adapter_type = Struct.new(:args)
    ActiveRecord::Type.register(:foo, type, override: false)
    ActiveRecord::Type.register(:foo, adapter_type, adapter: current_adapter)

    assert_equal adapter_type.new, ActiveRecord::Type.lookup(:foo)
  end

  test "adapter_name_from returns adapter symbol when connection exists" do
    assert_equal ActiveRecord::Base.connection_db_config.adapter.to_sym,
                 ActiveRecord::Type.adapter_name_from(ActiveRecord::Base)
  end

  test "adapter_name_from returns nil when ActiveRecord::ConnectionNotDefined is raised" do
    model = Minitest::Mock.new
    model.expect(:connection_db_config, nil) do
      raise ActiveRecord::ConnectionNotDefined
    end

    assert_nil ActiveRecord::Type.adapter_name_from(model)
  end
end
