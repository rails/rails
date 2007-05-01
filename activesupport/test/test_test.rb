require File.dirname(__FILE__) + '/abstract_unit'

class AssertDifferenceTest < Test::Unit::TestCase
  
  def setup
    @object = Class.new { attr_accessor :num }.new    
  end
  
  def test_assert_no_difference
    @object.num = 0
    
    assert_no_difference @object, :num do
      # ...
    end
      
  end
  def test_assert_difference
    @object.num = 0
    
    
    assert_difference @object, :num, +1 do
      @object.num = 1
    end
      
  end

  def test_methods_available
    
    assert self.respond_to?(:assert_difference)
    assert self.respond_to?(:assert_no_difference)
    
  end

end
