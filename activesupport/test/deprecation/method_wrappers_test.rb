# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/deprecation"

class MethodWrappersTest < ActiveSupport::TestCase
  def setup
    @klass = Class.new do
      def new_method; "abc" end
      alias_method :old_method, :new_method

      protected
        def new_protected_method; "abc" end
        alias_method :old_protected_method, :new_protected_method

      private
        def new_private_method; "abc" end
        alias_method :old_private_method, :new_private_method
    end

    @deprecator = ActiveSupport::Deprecation.new
  end

  def test_deprecate_methods_without_alternate_method
    @deprecator.deprecate_methods(@klass, :old_method)

    assert_deprecated("old_method", @deprecator) do
      assert_equal @klass.new.new_method, @klass.new.old_method
    end
  end

  def test_deprecate_methods_warning_default
    @deprecator.deprecate_methods(@klass, old_method: :new_method)

    assert_deprecated(/old_method .* \(use new_method instead\)/, @deprecator) do
      assert_equal @klass.new.new_method, @klass.new.old_method
    end
  end

  def test_deprecate_methods_warning_with_optional_deprecator
    @deprecator = ActiveSupport::Deprecation.new("next-release", "MyGem")
    other_deprecator = ActiveSupport::Deprecation.new
    other_deprecator.deprecate_methods(@klass, :old_method, deprecator: @deprecator)

    assert_deprecated(/old_method .* MyGem next-release/, @deprecator) do
      assert_not_deprecated(other_deprecator) do
        assert_equal @klass.new.new_method, @klass.new.old_method
      end
    end
  end

  def test_deprecate_methods_protected_method
    @deprecator.deprecate_methods(@klass, old_protected_method: :new_protected_method)

    assert(@klass.protected_method_defined?(:old_protected_method))
  end

  def test_deprecate_methods_private_method
    @deprecator.deprecate_methods(@klass, old_private_method: :new_private_method)

    assert(@klass.private_method_defined?(:old_private_method))
  end

  def test_deprecate_class_method
    mod = Module.new do
      extend self

      def old_method
        "abc"
      end
    end
    @deprecator.deprecate_methods(mod, :old_method)

    assert_deprecated("old_method", @deprecator) do
      assert_equal "abc", mod.old_method
    end
  end

  def test_deprecate_method_when_class_extends_module
    mod = Module.new do
      def old_method
        "abc"
      end
    end
    klass = Class.new { extend mod }
    @deprecator.deprecate_methods(mod, :old_method)

    assert_deprecated("old_method", @deprecator) do
      assert_equal "abc", klass.old_method
    end
  end
end
