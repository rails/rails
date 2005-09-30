require 'test/unit'

require File.dirname(__FILE__) + '/../lib/active_support/ordered_options'

class OrderedOptionsTest < Test::Unit::TestCase
  def test_usage
    a = OrderedOptions.new

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
end
