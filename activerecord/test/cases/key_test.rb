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
end
