require File.dirname(__FILE__) + '/abstract_unit'

class OrderedHashTest < Test::Unit::TestCase
  def setup
    @keys =   %w( blue   green  red    pink   orange )
    @values = %w( 000099 009900 aa0000 cc0066 cc6633 )
    @ordered_hash = ActiveSupport::OrderedHash.new

    @keys.each_with_index do |key, index|
      @ordered_hash[key] = @values[index]
    end
  end

  def test_order
    assert_equal @keys,   @ordered_hash.keys
    assert_equal @values, @ordered_hash.values
  end

  def test_access
    assert @keys.zip(@values).all? { |k, v| @ordered_hash[k] == v }
  end

  def test_assignment
    key, value = 'purple', '5422a8'

    @ordered_hash[key] = value
    assert_equal @keys.length + 1, @ordered_hash.length
    assert_equal key, @ordered_hash.keys.last
    assert_equal value, @ordered_hash.values.last
    assert_equal value, @ordered_hash[key]
  end
end

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

  def test_looping
    a = OrderedOptions.new

    a[:allow_concurreny] = true
    a["else_where"] = 56

    test = [[:allow_concurreny, true], [:else_where, 56]]

    a.each_with_index do |(key, value), index|
      assert_equal test[index].first, key
      assert_equal test[index].last, value
    end
  end

  def test_method_access
    a = OrderedOptions.new

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
