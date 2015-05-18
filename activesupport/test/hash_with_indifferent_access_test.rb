require 'abstract_unit'
require 'active_support/hash_with_indifferent_access'

class HashWithIndifferentAccessTest < ActiveSupport::TestCase
  def test_reverse_merge
    hash = HashWithIndifferentAccess.new key: :old_value
    hash.reverse_merge! key: :new_value
    assert_equal :old_value, hash[:key]
  end

  def test_select_with_block
    hash = HashWithIndifferentAccess.new({ a: 1, b: 2, c: 3 })
    assert_equal hash.select { |k, v| true }, hash
  end

  def test_select_without_block
    hash = HashWithIndifferentAccess.new({ a: 1, b: 2, c: 3 })
    assert_instance_of Enumerator, hash.select
  end
end
