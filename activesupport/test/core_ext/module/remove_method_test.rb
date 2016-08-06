require "abstract_unit"
require "active_support/core_ext/module/remove_method"

module RemoveMethodTests
  class A
    def do_something
      return 1
    end

    def do_something_protected
      return 1
    end
    protected :do_something_protected

    def do_something_private
      return 1
    end
    private :do_something_private

    class << self
      def do_something_else
        return 2
      end
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

  def test_remove_singleton_method_from_an_object
    RemoveMethodTests::A.class_eval{
      self.remove_possible_singleton_method(:do_something_else)
    }
    assert !RemoveMethodTests::A.respond_to?(:do_something_else)
  end

  def test_redefine_method_in_an_object
    RemoveMethodTests::A.class_eval{
      self.redefine_method(:do_something) { return 100 }
      self.redefine_method(:do_something_protected) { return 100 }
      self.redefine_method(:do_something_private) { return 100 }
    }
    assert_equal 100, RemoveMethodTests::A.new.do_something
    assert_equal 100, RemoveMethodTests::A.new.send(:do_something_protected)
    assert_equal 100, RemoveMethodTests::A.new.send(:do_something_private)

    assert RemoveMethodTests::A.public_method_defined? :do_something
    assert RemoveMethodTests::A.protected_method_defined? :do_something_protected
    assert RemoveMethodTests::A.private_method_defined? :do_something_private
  end
end
