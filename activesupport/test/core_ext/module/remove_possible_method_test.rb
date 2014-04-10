require 'abstract_unit'
require 'active_support/core_ext/module/remove_possible_method'

module RemovePossibleMethodTests
  class A
    def do_something
      1
    end
  end
end

class RemovePossibleMethodTest < ActiveSupport::TestCase

  def test_remove_possible_method_from_an_object
    RemovePossibleMethodTests::A.class_eval{
      self.remove_possible_method(:do_something)
    }
    assert !RemovePossibleMethodTests::A.new.respond_to?(:do_something)
  end

end