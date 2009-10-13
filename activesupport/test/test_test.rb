require 'abstract_unit'
require 'active_support/core_ext/kernel/reporting'

class AssertDifferenceTest < ActiveSupport::TestCase
  def setup
    @object = Class.new do
      attr_accessor :num
      def increment
        self.num += 1
      end

      def decrement
        self.num -= 1
      end
    end.new
    @object.num = 0
  end

  if lambda { }.respond_to?(:binding)
    def test_assert_no_difference
      assert_no_difference '@object.num' do
        # ...
      end
    end

    def test_assert_difference
      assert_difference '@object.num', +1 do
        @object.increment
      end
    end

    def test_assert_difference_with_implicit_difference
      assert_difference '@object.num' do
        @object.increment
      end
    end

    def test_arbitrary_expression
      assert_difference '@object.num + 1', +2 do
        @object.increment
        @object.increment
      end
    end

    def test_negative_differences
      assert_difference '@object.num', -1 do
        @object.decrement
      end
    end

    def test_expression_is_evaluated_in_the_appropriate_scope
      local_scope = 'foo'
      silence_warnings do
        assert_difference('local_scope; @object.num') { @object.increment }
      end
    end

    def test_array_of_expressions
      assert_difference [ '@object.num', '@object.num + 1' ], +1 do
        @object.increment
      end
    end

    def test_array_of_expressions_identify_failure
      assert_difference ['@object.num', '1 + 1'] do
        @object.increment
      end
      fail 'should not get to here'
    rescue Exception => e
      assert_match(/didn't change by/, e.message)
      assert_match(/expected but was/, e.message)
    end

    def test_array_of_expressions_identify_failure_when_message_provided
      assert_difference ['@object.num', '1 + 1'], 1, 'something went wrong' do
        @object.increment
      end
      fail 'should not get to here'
    rescue Exception => e
      assert_match(/something went wrong/, e.message)
      assert_match(/didn't change by/, e.message)
      assert_match(/expected but was/, e.message)
    end
  else
    def default_test; end
  end
end

# These should always pass
if ActiveSupport::Testing.const_defined?(:Default)
  class NotTestingThingsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Default
  end
end

class AlsoDoingNothingTest < ActiveSupport::TestCase
end
