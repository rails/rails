require 'abstract_unit'
require 'active_support/whiny_nil'

class WhinyNilTest < Test::Unit::TestCase
  def test_id
    nil.id
  rescue RuntimeError => nme
    assert_no_match(/nil:NilClass/, nme.message)
    assert_match(Regexp.new(nil.object_id.to_s), nme.message)
  end
end
