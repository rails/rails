# frozen_string_literal: true

require_relative "abstract_unit"

class WeakSetTest < ActiveSupport::TestCase
  def test_each_yields_the_members
    a, b = Object.new, Object.new
    set = ActiveSupport::WeakSet.new
    set << a
    set << b

    assert_equal Set[a, b], set.to_enum(:each).to_set
  end

  def test_dup_copies_the_members
    a, b = Object.new, Object.new
    set = ActiveSupport::WeakSet.new
    set << a

    copy = set.dup
    copy << b

    assert_includes copy, a
    assert_includes copy, b
    assert_not_includes set, b
  end
end
