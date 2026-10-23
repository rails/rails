# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/deprecation"
require "active_support/core_ext/object/inclusion"
require "active_support/core_ext/object/json"
require "active_support/core_ext/object/to_query"

class ProxyWrappersTest < ActiveSupport::TestCase
  Waffles     = false
  NewWaffles  = :hamburgers

  module WaffleModule
    def waffle?
      true
    end
  end

  def setup
    @deprecator = ActiveSupport::Deprecation.new
  end

  def test_deprecated_object_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(nil, "message")
    assert_not proxy
  end

  def test_deprecated_instance_variable_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(nil, :waffles)
    assert_not proxy
  end

  def test_deprecated_constant_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(Waffles, NewWaffles)
    assert_not proxy
  end

  def test_including_proxy_module
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("OldWaffleModule", WaffleModule.name, @deprecator)
    klass = Class.new
    assert_deprecated("OldWaffleModule", @deprecator) do
      klass.include proxy
    end
    assert_predicate klass.new, :waffle?
  end

  def test_prepending_proxy_module
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("OldWaffleModule", WaffleModule.name, @deprecator)
    klass = Class.new do
      def waffle?
        false
      end
    end
    assert_deprecated("OldWaffleModule", @deprecator) do
      klass.prepend proxy
    end
    assert_predicate klass.new, :waffle?
  end

  def test_extending_proxy_module
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new("OldWaffleModule", WaffleModule.name, @deprecator)
    obj = Object.new
    assert_deprecated("OldWaffleModule", @deprecator) do
      obj.extend proxy
    end
    assert_predicate obj, :waffle?
  end

  def test_deprecated_object_proxy_forwards_methods_added_to_object_after_load
    proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new([1, 2, 3], "array is deprecated", @deprecator)

    assert_deprecated("array is deprecated", @deprecator) do
      assert_equal "[1,2,3]", proxy.to_json
    end
    assert_deprecated("array is deprecated", @deprecator) do
      assert_equal "1/2/3", proxy.to_param
    end
    assert_deprecated("array is deprecated", @deprecator) do
      assert proxy.in?([[1, 2, 3]])
    end
  end

  def test_deprecated_object_proxy_forwards_comparison_and_evaluation
    proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new([1, 2, 3], "array is deprecated", @deprecator)

    assert_deprecated("array is deprecated", @deprecator) do
      assert_equal true, proxy == [1, 2, 3]
    end
    assert_deprecated("array is deprecated", @deprecator) do
      assert_equal false, !proxy
    end
    assert_deprecated("array is deprecated", @deprecator) do
      assert_equal 3, proxy.instance_eval { size }
    end
  end

  def test_deprecated_object_proxy_keeps_its_own_object_id
    object = Object.new
    proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(object, "message", @deprecator)

    assert_not_deprecated(@deprecator) do
      assert_not_equal object.object_id, proxy.object_id
    end
  end
end
