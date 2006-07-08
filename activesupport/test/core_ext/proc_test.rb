require File.dirname(__FILE__) + '/../abstract_unit'

class ProcTests < Test::Unit::TestCase
  def test_bind_returns_method_with_changed_self
    block = Proc.new { self }
    assert_equal self, block.call
    bound_block = block.bind("hello")
    assert_not_equal block, bound_block
    assert_equal "hello", bound_block.call
  end
end
