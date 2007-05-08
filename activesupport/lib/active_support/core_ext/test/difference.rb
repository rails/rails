module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:      
      # Test numeric difference between the return value of an expression as a result of what is evaluated
      # in the yielded block.
      #
      #   assert_difference 'Article.count' do
      #     post :create, :article => {...}
      #   end
      #
      # An arbitrary expression is passed in and evaluated.
      #
      #   assert_difference 'assigns(:article).comments(:reload).size' do
      #     post :create, :comment => {...}
      #   end
      #
      # An arbitrary positive or negative difference can be specified. The default is +1.
      #
      #   assert_difference 'Article.count', -1 do
      #     post :delete, :id => ...
      #   end
      def assert_difference(expression, difference = 1, &block)
        expression_evaluation = lambda { eval(expression, block.binding) }
        original_value        = expression_evaluation.call
        yield
        assert_equal original_value + difference, expression_evaluation.call
      end

      # Assertion that the numeric result of evaluating an expression is not changed before and after
      # invoking the passed in block.
      #
      #   assert_no_difference 'Article.count' do
      #     post :create, :article => invalid_attributes
      #   end
      def assert_no_difference(expression, &block)
        assert_difference expression, 0, &block
      end
    end
  end
end
