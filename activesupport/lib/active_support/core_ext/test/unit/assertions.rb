module Test #:nodoc:
  module Unit #:nodoc:
    # FIXME: no Proc#binding in Ruby 2, must change this API
    module Assertions #:nodoc:
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
      #
      # An array of expressions can also be passed in and evaluated.
      #
      #   assert_difference [ 'Article.count', 'Post.count' ], +2 do
      #     post :create, :article => {...}
      #   end
      #
      # A error message can be specified.
      #
      #   assert_difference 'Article.count', -1, "An Article should be destroyed" do
      #     post :delete, :id => ...
      #   end
      def assert_difference(expressions, difference = 1, message = nil, &block)
        expression_evaluations = Array(expressions).collect{ |expression| lambda { eval(expression, block.send!(:binding)) } }

        original_values = expression_evaluations.inject([]) { |memo, expression| memo << expression.call }
        yield
        expression_evaluations.each_with_index do |expression, i|
          assert_equal original_values[i] + difference, expression.call, message
        end
      end

      # Assertion that the numeric result of evaluating an expression is not changed before and after
      # invoking the passed in block.
      #
      #   assert_no_difference 'Article.count' do
      #     post :create, :article => invalid_attributes
      #   end
      #
      # A error message can be specified.
      #
      #   assert_no_difference 'Article.count', "An Article should not be destroyed" do
      #     post :create, :article => invalid_attributes
      #   end
      def assert_no_difference(expressions, message = nil, &block)
        assert_difference expressions, 0, message, &block
      end
    end
  end
end
