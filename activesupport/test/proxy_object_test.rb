# frozen_string_literal: true

require_relative "abstract_unit"

class ProxyObjectTest < ActiveSupport::TestCase
  def test_accessing_proxy_object_is_deprecated
    proxy = assert_deprecated(ActiveSupport.deprecator) do
      Class.new(ActiveSupport::ProxyObject) do
        def some_method
          "foo"
        end
      end
    end
    assert_equal("foo", proxy.new.some_method)
  end
end
