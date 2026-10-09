# frozen_string_literal: true

require "cases/helper"
require "models/cpk"
require "models/topic"

class KeyTest < ActiveRecord::TestCase
  Key = ActiveRecord::Key

  def test_for_dispatches_to_polymorphic_subclass
    assert_instance_of Key::Single, Key.for("id")
    assert_instance_of Key::Composite, Key.for([:shop_id, :id])
    assert_instance_of Key::None, Key.for(nil)

    assert_kind_of Key, Key.for("id")
    assert_kind_of Key, Key.for([:shop_id, :id])
  end

  def test_simple_key_shape
    pk = Key.for("id")

    assert_not_predicate pk, :composite?
    assert_predicate pk, :present?
    assert_equal "id", pk.name
    assert_equal ["id"], pk.columns
    assert_equal 1, pk.length
  end

  def test_composite_key_shape
    pk = Key.for([:shop_id, :id])

    assert_predicate pk, :composite?
    assert_predicate pk, :present?
    assert_equal ["shop_id", "id"], pk.name
    assert_equal ["shop_id", "id"], pk.columns
    assert_equal 2, pk.length
  end

  def test_missing_key
    pk = Key.for(nil)

    assert_not_predicate pk, :composite?
    assert_not_predicate pk, :present?
    assert_nil pk.name
    assert_empty pk.columns
  end

  def test_columns_are_frozen_strings
    pk = Key.for([:shop_id, :id])

    assert pk.columns.frozen?
    assert(pk.columns.all?(&:frozen?))
  end

  def test_map_value_returns_a_scalar_without_wrapping_it
    value = [10, 20]
    columns = []
    result = Key.for(:payload).map_value do |column|
      columns << column
      value
    end

    assert_equal ["payload"], columns
    assert_same value, result
    assert_same value, Key.for(:payload).map_value.with_index { |_column, index| [value][index] }
    assert_nil Key.for(:payload).map_value { nil }
    assert_equal false, Key.for(:payload).map_value { false }
  end

  def test_map_value_preserves_composite_shape_and_component_values
    value = [10, 20]
    attributes = { "tenant_id" => 7, "payload" => value }
    result = Key.for([:tenant_id, :payload]).map_value { |column| attributes.fetch(column) }

    assert_equal [7, value], result
    assert_same value, result.last
    assert_equal [nil, false], Key.for([:missing, :disabled]).map_value { |column| column == "disabled" ? false : nil }
    assert_equal [value], Key.for([:payload]).map_value { value }
    assert_equal [7, value], Key.for([:tenant_id, :payload]).map_value.with_index { |_column, index| [7, value][index] }
  end

  def test_where_hash_for_simple_key
    assert_equal({ "id" => 5 }, Key.for("id").where_hash(5))
    assert_equal({ "id" => [1, 2, 3] }, Key.for("id").where_hash([1, 2, 3]))
  end

  def test_where_hash_for_composite_key
    pk = Key.for([:shop_id, :id])

    assert_equal({ "shop_id" => 1, "id" => 5 }, pk.where_hash([1, 5]))
  end

  def test_expects_multiple_ids_for_simple_key
    pk = Key.for("id")

    assert_not pk.expects_multiple_ids?(5)
    assert pk.expects_multiple_ids?([1, 2, 3])
    assert pk.expects_multiple_ids?([])
  end

  def test_expects_multiple_ids_for_composite_key
    pk = Key.for([:shop_id, :id])

    # A single composite id is itself an Array...
    assert_not pk.expects_multiple_ids?([1, 5])
    # ...so several ids are an Array of Arrays.
    assert pk.expects_multiple_ids?([[1, 5], [1, 6]])
    # ...and an empty Array is an empty set of ids.
    assert pk.expects_multiple_ids?([])
  end

  def test_inferred_id_picks_id_from_tenant_shaped_key
    assert_equal "id", Key.for([:shop_id, :id]).inferred_id
    assert_equal ["shop_id", "owner_id"], Key.for([:shop_id, :owner_id]).inferred_id
    assert_nil Key.for("id").inferred_id
  end

  def test_cast_uses_model_column_types
    pk = Cpk::Book.primary_key_definition

    assert_predicate pk, :composite?
    assert_equal [1, 3], pk.cast(["1", "3"], Cpk::Book)

    assert_equal 5, Topic.primary_key_definition.cast("5", Topic)
  end

  def test_value_of_reads_attributes_from_record
    book = Cpk::Book.new(id: [1, 3])
    assert_equal [1, 3], Cpk::Book.primary_key_definition.value_of(book)

    topic = Topic.new(id: 7)
    assert_equal 7, Topic.primary_key_definition.value_of(topic)
  end

  def test_model_exposes_definition
    assert_not_predicate Topic.primary_key_definition, :composite?
    assert_equal "id", Topic.primary_key_definition.name

    assert_predicate Cpk::Book.primary_key_definition, :composite?
    assert_equal ["author_id", "id"], Cpk::Book.primary_key_definition.name
  end

  def test_include
    assert_includes Key.for("id"), "id"
    assert_not_includes Key.for("id"), "shop_id"
    assert_includes Key.for([:shop_id, :id]), "shop_id"
    assert_not_includes Key.for([:shop_id, :id]), "author_id"
    assert_not_includes Key.for(nil), "id"
  end

  def test_subset_of_single_key
    single = Key.for("id")

    assert single.subset?(Key.for("id"))
    assert_not single.subset?(Key.for("shop_id"))
    assert single.subset?(Key.for([:shop_id, :id]))
    assert_not single.subset?(Key.for([:shop_id, :author_id]))
    assert_not single.subset?(Key.for(nil))
  end

  def test_subset_of_composite_key
    composite = Key.for([:shop_id, :id])

    assert composite.subset?(Key.for([:id, :shop_id]))
    assert composite.subset?(Key.for([:shop_id, :id, :author_id]))
    assert_not composite.subset?(Key.for([:shop_id, :author_id]))
    assert_not composite.subset?(Key.for("id"))
    assert_not composite.subset?(Key.for(nil))
  end

  def test_zip
    [Key.for("id"), Key.for([:shop_id, :id]), Key.for(nil)].each do |key|
      other_columns = key.to_a.map { |column| "other_#{column}" }
      other = Key.for(key.composite? ? other_columns : other_columns.first)
      expected = key.to_a.zip(other.to_a)

      assert_equal expected, key.zip(other)
      assert_equal expected, key.zip(other.to_a)

      yielded = []
      assert_nil key.zip(other) { |column, other_column| yielded << [column, other_column] }
      assert_equal expected, yielded
    end
  end

  def test_none_is_a_subset_of_every_key
    none = Key.for(nil)

    assert none.subset?(Key.for("id"))
    assert none.subset?(Key.for([:shop_id, :id]))
    assert none.subset?(Key.for(nil))
  end
end
