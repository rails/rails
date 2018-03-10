# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/array"

class SmooshTest < ActiveSupport::TestCase
  def test_smoosh
    assert_equal [1, 2, 3, 4], [1, [2], [[3, 4]]].smoosh
  end
end
