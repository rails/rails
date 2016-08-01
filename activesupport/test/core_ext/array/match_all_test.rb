require 'abstract_unit'
require 'active_support/core_ext/array'

class MatchAllTest < ActiveSupport::TestCase
  def test_string_array
    ary = ['ham', 'cheese', 'Bob Saget']
    assert_equal ['Bob Saget'], ary.match_all(/Saget/)
  end

  def test_nil_array
    ary = ['ham', 'cheese', nil]
    assert_equal ['ham','cheese'], ary.match_all(/./)
  end

  def test_object_array
    ary = [Object.new, [], {}]
    assert_equal [] , ary.match_all(/cheese/) 
  end
end
