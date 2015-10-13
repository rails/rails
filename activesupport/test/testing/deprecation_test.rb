require 'abstract_unit'
require 'active_support/deprecation'

class DeprecationTestingTest < ActiveSupport::TestCase
  def setup
    @klass = Class.new do
      def new_method; "abc" end
      alias_method :old_method, :new_method
    end
  end

  def test_assert_deprecated_raises_when_method_not_deprecated
    assert_raises(Minitest::Assertion) { assert_deprecated { @klass.new.old_method } }
  end

  def test_assert_not_deprecated
    ActiveSupport::Deprecation.deprecate_methods(@klass, :old_method => :new_method)

    assert_raises(Minitest::Assertion) { assert_not_deprecated { @klass.new.old_method } }
  end
end
