require 'abstract_unit'
require 'active_support/core_ext/hash/slice'

class FetchAllTest < ActiveSupport::TestCase
  test "fetch_all returns a new hash with the keys specified by arguments" do
    original = { a: 'a', b: 'b', c: 'c' }
    mapped = original.fetch_all(:a, :b)

    assert_equal({ a: 'a', b: 'b' }, mapped)
  end

  test "fetch_all raises a KeyError if any of the required keys is missing" do
    assert_raise KeyError do
      { a: 'a', b: 'b' }.fetch_all(:a, :x)
    end
  end
end
