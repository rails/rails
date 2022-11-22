# frozen_string_literal: true

require "cases/helper"
require "models/clothing_item"

class QueryConstraintsTest < ActiveRecord::TestCase
  def test_primary_key_stays_the_same
    assert_equal("id", ClothingItem.primary_key)
  end

  def test_query_constraints_list_is_an_array_of_strings
    assert_equal(["clothing_type", "color"], ClothingItem.query_constraints_list)
  end
end
