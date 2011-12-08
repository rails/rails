require 'abstract_unit'
require 'active_support/whiny_nil'

class WhinyNilTest < Test::Unit::TestCase
  def test_id
    nil.stubs(:object_id).returns(999)
    nil.id
  rescue RuntimeError => nme
    assert_no_match(/nil:NilClass/, nme.message)
    assert_match(/999/, nme.message)
  end
end
