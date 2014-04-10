require 'abstract_unit'
require 'active_support/core_ext/module/redefine_method'

module RedefineMethodTests
  class A
    def do_something
      1
    end
  end
end

class RedefineMethodTest < ActiveSupport::TestCase

  def test_redefine_method_in_an_object
    RedefineMethodTests::A.class_eval{
      self.redefine_method(:do_something) { 100 }
    }
    assert_equal 100, RedefineMethodTests::A.new.do_something
  end

end