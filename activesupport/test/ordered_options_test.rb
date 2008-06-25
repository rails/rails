require 'abstract_unit'

class OrderedOptionsTest < Test::Unit::TestCase
  def test_usage
    a = ActiveSupport::OrderedOptions.new

    assert_nil a[:not_set]

    a[:allow_concurreny] = true
    assert_equal 1, a.size
    assert a[:allow_concurreny]

    a[:allow_concurreny] = false
    assert_equal 1, a.size
    assert !a[:allow_concurreny]

    a["else_where"] = 56
    assert_equal 2, a.size
    assert_equal 56, a[:else_where]
  end

  def test_looping
    a = ActiveSupport::OrderedOptions.new

    a[:allow_concurreny] = true
    a["else_where"] = 56

    test = [[:allow_concurreny, true], [:else_where, 56]]

    a.each_with_index do |(key, value), index|
      assert_equal test[index].first, key
      assert_equal test[index].last, value
    end
  end

  def test_method_access
    a = ActiveSupport::OrderedOptions.new

    assert_nil a.not_set

    a.allow_concurreny = true
    assert_equal 1, a.size
    assert a.allow_concurreny

    a.allow_concurreny = false
    assert_equal 1, a.size
    assert !a.allow_concurreny

    a.else_where = 56
    assert_equal 2, a.size
    assert_equal 56, a.else_where
  end
end
