require 'test/unit'
require File.dirname(__FILE__) + '/../lib/active_support/deprecation'

# Stub out the warnings to allow assertions
module ActiveSupport
  module Deprecation
    class << self
      def issue_warning(message)
        @@warning = message
      end
      def last_warning
        @@warning
      end
    end
  end
end

class DeprecationTestingClass

  def partiallly_deprecated(foo = nil)
    if foo.nil?
      ActiveSupport::Deprecation.issue_warning("calling partially_deprecated with foo=nil is now deprecated")
    end
  end
  
  def not_deprecated
    2
  end
  
  def deprecated_no_args
    1
  end
  deprecate :deprecated_no_args
  
  def deprecated_one_arg(a)
    a
  end
  deprecate :deprecated_one_arg
  
  def deprecated_multiple_args(a,b,c)
    [a,b,c]
  end
  deprecate :deprecated_multiple_args
  
end


class DeprecationTest < Test::Unit::TestCase
  def setup
    @dtc = DeprecationTestingClass.new
    ActiveSupport::Deprecation.issue_warning(nil) # reset
  end
  
  def test_partial_deprecation
    @dtc.partiallly_deprecated
    assert_warning_matches /foo=nil/
  end
  
  def test_raises_nothing
    assert_equal 2, @dtc.not_deprecated
  end
  
  def test_deprecating_class_method
    assert_equal 1, @dtc.deprecated_no_args
    assert_deprecation_warning
    assert_warning_matches /DeprecationTestingClass#deprecated_no_args/
  end
  
  def test_deprecating_class_method_with_argument
    assert_equal 1, @dtc.deprecated_one_arg(1)
  end
  
  def test_deprecating_class_method_with_argument
    assert_equal [1,2,3], @dtc.deprecated_multiple_args(1,2,3)
  end
  
  private
  def assert_warning_matches(rx)
    assert ActiveSupport::Deprecation.last_warning =~ rx, "The deprecation warning did not match #{rx}"
  end
  
  def assert_deprecation_warning
    assert_not_nil ActiveSupport::Deprecation.last_warning, "No Deprecation warnings were issued"
  end
end
