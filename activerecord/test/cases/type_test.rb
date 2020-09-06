# frozen_string_literal: true

require 'cases/helper'

class TypeTest < ActiveRecord::TestCase
  setup do
    @old_registry = ActiveRecord::Type.registry
    ActiveRecord::Type.registry = ActiveRecord::Type::AdapterSpecificRegistry.new
  end

  teardown do
    ActiveRecord::Type.registry = @old_registry
  end

  test 'registering a new type' do
    type = Struct.new(:args)
    ActiveRecord::Type.register(:foo, type)

    assert_equal type.new(:arg), ActiveRecord::Type.lookup(:foo, :arg)
  end

  test 'looking up a type for a specific adapter' do
    type = Struct.new(:args)
    pgtype = Struct.new(:args)
    ActiveRecord::Type.register(:foo, type, override: false)
    ActiveRecord::Type.register(:foo, pgtype, adapter: :postgresql)

    assert_equal type.new, ActiveRecord::Type.lookup(:foo, adapter: :sqlite)
    assert_equal pgtype.new, ActiveRecord::Type.lookup(:foo, adapter: :postgresql)
  end

  test 'lookup defaults to the current adapter' do
    current_adapter = ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    type = Struct.new(:args)
    adapter_type = Struct.new(:args)
    ActiveRecord::Type.register(:foo, type, override: false)
    ActiveRecord::Type.register(:foo, adapter_type, adapter: current_adapter)

    assert_equal adapter_type.new, ActiveRecord::Type.lookup(:foo)
  end
end
