require 'abstract_unit'
require 'active_support/core_ext/module/remove_method'

module RemoveMethodTests
  class A
    def do_something
      return 1
    end
    
  end
end

class RemoveMethodTest < ActiveSupport::TestCase
  
  def test_remove_method_from_an_object
    RemoveMethodTests::A.class_eval{
      self.remove_possible_method(:do_something)
    }
    assert !RemoveMethodTests::A.new.respond_to?(:do_something)
  end
  
  def test_redefine_method_in_an_object
    RemoveMethodTests::A.class_eval{
      self.redefine_method(:do_something) { return 100 }
    }
    assert_equal 100, RemoveMethodTests::A.new.do_something
  end

end