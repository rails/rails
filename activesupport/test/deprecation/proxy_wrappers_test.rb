# frozen_string_literal: true

require "abstract_unit"
require "active_support/deprecation"

class ProxyWrappersTest < ActiveSupport::TestCase
  Waffles     = false
  NewWaffles  = :hamburgers

  def test_deprecated_object_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedObjectProxy.new(nil, "message")
    assert !proxy
  end

  def test_deprecated_instance_variable_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new(nil, :waffles)
    assert !proxy
  end

  def test_deprecated_constant_proxy_doesnt_wrap_falsy_objects
    proxy = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(Waffles, NewWaffles)
    assert !proxy
  end
end
