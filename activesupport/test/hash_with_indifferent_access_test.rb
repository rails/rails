require 'abstract_unit'
require 'active_support/hash_with_indifferent_access'

class HashWithIndifferentAccessTest < ActiveSupport::TestCase
  def test_reverse_merge
    hash = HashWithIndifferentAccess.new key: :old_value
    hash.reverse_merge! key: :new_value
    assert_equal :old_value, hash[:key]
  end

  def test_frozen_value
    value = [1, 2, 3].freeze
    hash = {}.with_indifferent_access
    hash[:key] = value
    assert_equal hash[:key], value
  end
end