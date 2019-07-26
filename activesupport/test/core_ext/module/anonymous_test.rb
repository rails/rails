# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/module/anonymous"

class AnonymousTest < ActiveSupport::TestCase
  test "an anonymous class or module are anonymous" do
    assert_predicate Module.new, :anonymous?
    assert_predicate Class.new, :anonymous?
  end

  test "a named class or module are not anonymous" do
    assert_not_predicate Kernel, :anonymous?
    assert_not_predicate Object, :anonymous?
  end
end
