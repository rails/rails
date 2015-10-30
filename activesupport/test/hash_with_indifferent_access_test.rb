require 'abstract_unit'
require 'active_support/hash_with_indifferent_access'

class HashWithIndifferentAccessTest < ActiveSupport::TestCase
  def test_frozen_value
    value = [1, 2, 3].freeze
    hash = {}.with_indifferent_access
    hash[:key] = value
    assert_equal hash[:key], value
  end
end
