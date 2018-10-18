# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/module/reachable"

class AnonymousTest < ActiveSupport::TestCase
  test "an anonymous class or module is not reachable" do
    assert_deprecated do
      assert_not_predicate Module.new, :reachable?
      assert_not_predicate Class.new, :reachable?
    end
  end

  test "ordinary named classes or modules are reachable" do
    assert_deprecated do
      assert_predicate Kernel, :reachable?
      assert_predicate Object, :reachable?
    end
  end

  test "a named class or module whose constant has gone is not reachable" do
    c = eval "class C; end; C"
    m = eval "module M; end; M"

    self.class.send(:remove_const, :C)
    self.class.send(:remove_const, :M)

    assert_deprecated do
      assert_not_predicate c, :reachable?
      assert_not_predicate m, :reachable?
    end
  end

  test "a named class or module whose constants store different objects are not reachable" do
    c = eval "class C; end; C"
    m = eval "module M; end; M"

    self.class.send(:remove_const, :C)
    self.class.send(:remove_const, :M)

    eval "class C; end"
    eval "module M; end"

    assert_deprecated do
      assert_predicate C, :reachable?
      assert_predicate M, :reachable?
      assert_not_predicate c, :reachable?
      assert_not_predicate m, :reachable?
    end
  end
end
