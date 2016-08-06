require "abstract_unit"
require "active_support/core_ext/module/reachable"

class AnonymousTest < ActiveSupport::TestCase
  test "an anonymous class or module is not reachable" do
    assert !Module.new.reachable?
    assert !Class.new.reachable?
  end

  test "ordinary named classes or modules are reachable" do
    assert Kernel.reachable?
    assert Object.reachable?
  end

  test "a named class or module whose constant has gone is not reachable" do
    c = eval "class C; end; C"
    m = eval "module M; end; M"

    self.class.send(:remove_const, :C)
    self.class.send(:remove_const, :M)

    assert !c.reachable?
    assert !m.reachable?
  end

  test "a named class or module whose constants store different objects are not reachable" do
    c = eval "class C; end; C"
    m = eval "module M; end; M"

    self.class.send(:remove_const, :C)
    self.class.send(:remove_const, :M)

    eval "class C; end"
    eval "module M; end"

    assert C.reachable?
    assert M.reachable?
    assert !c.reachable?
    assert !m.reachable?
  end
end