# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/array"

class PrependAppendTest < ActiveSupport::TestCase
  def test_append
    assert_equal [1, 2], [1].append(2)
  end

  def test_prepend
    assert_equal [2, 1], [1].prepend(2)
  end
end
