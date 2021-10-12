# frozen_string_literal: true

require_relative "abstract_unit"

class PerThreadRegistryTest < ActiveSupport::TestCase
  class TestRegistry
    extend ActiveSupport::PerThreadRegistry

    def foo(x:); x; end
  end

  def test_method_missing_with_kwargs
    assert_equal 1, TestRegistry.foo(x: 1)
  end
end
