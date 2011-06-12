require "cases/helper"
require "models/secure_person"

class CustomRelationTest < ActiveRecord::TestCase
  def test_scope_returns_the_custom_relation
    assert_equal SecurePerson.scoped.class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_where
    assert_equal SecurePerson.where(:name => "test").class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_select
    assert_equal SecurePerson.select(:name).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_group
    assert_equal SecurePerson.group(:parent).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_order
    assert_equal SecurePerson.order(:name).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_except
    assert_equal SecurePerson.except(:name).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_reorder
    assert_equal SecurePerson.reorder(:name).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_limit
    assert_equal SecurePerson.limit(5).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_offset
    assert_equal SecurePerson.offset(5).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_joins
    assert_equal SecurePerson.joins(:parent).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_where
    assert_equal SecurePerson.where(:name => "test").class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_preload
    assert_equal SecurePerson.preload(:parent).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_eager_load
    assert_equal SecurePerson.eager_load(:parent).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_includes
    assert_equal SecurePerson.includes(:parent).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_from
    assert_equal SecurePerson.from(:secure_people).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_lock
    assert_equal SecurePerson.lock(:name).class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_readonly
    assert_equal SecurePerson.readonly.class, EncryptedRelation
  end

  def test_spawns_the_custom_relation_on_having
    assert_equal SecurePerson.having(:name => "test").class, EncryptedRelation
  end
end
