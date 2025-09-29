# frozen_string_literal: true

require_relative "../../abstract_unit"
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

  test "anonymous class or module remains anonymous despite overriding name method" do
    anonymous_module = Module.new do
      def self.name
        "FakeName"
      end
    end
    anonymous_class = Class.new do
      def self.name
        "FakeName"
      end
    end

    assert_predicate anonymous_module, :anonymous?
    assert_predicate anonymous_class, :anonymous?
  end

  test "overridden name method does not interfere with anonymous detection for constants" do
    test_module = Module.new do
      def self.name
        raise NotImplementedError
      end
    end
    test_class = Class.new do
      def self.name
        raise NotImplementedError
      end
    end

    # Assign to constants to make them non-anonymous
    self.class.const_set(:TestModule, test_module)
    self.class.const_set(:TestClass, test_class)

    assert_not_predicate self.class::TestModule, :anonymous?
    assert_not_predicate self.class::TestClass, :anonymous?
  ensure
    self.class.send(:remove_const, :TestModule) if self.class.const_defined?(:TestModule)
    self.class.send(:remove_const, :TestClass) if self.class.const_defined?(:TestClass)
  end
end
