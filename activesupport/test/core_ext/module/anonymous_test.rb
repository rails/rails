require "abstract_unit"
require "active_support/core_ext/module/anonymous"

class AnonymousTest < ActiveSupport::TestCase
  test "an anonymous class or module are anonymous" do
    assert Module.new.anonymous?
    assert Class.new.anonymous?
  end

  test "a named class or module are not anonymous" do
    assert !Kernel.anonymous?
    assert !Object.anonymous?
  end
end
