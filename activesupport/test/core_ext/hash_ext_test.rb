require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/core_ext/hash_ext'

class HashExtTest < Test::Unit::TestCase
  def test_assert_valid_keys
    assert_nothing_raised do
      { :failure => "stuff", :funny => "business" }.assert_valid_keys([ :failure, :funny ])
    end
    
    assert_raises(ArgumentError, "Unknown key(s): failore") do
      { :failore => "stuff", :funny => "business" }.assert_valid_keys([ :failure, :funny ])
    end
  end
end