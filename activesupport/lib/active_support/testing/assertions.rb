module ActiveSupport
  module Testing
    module Assertions
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
        case expressions
        when String
          before = eval(expressions, block.send(:binding))
          yield
          assert_equal(before + difference, eval(expressions, block.send(:binding)), message)
        when Enumerable
          expressions.each { |e| assert_difference(e, difference, message, &block) }
        else
          raise ArgumentError, "Unrecognized expression: #{expressions.inspect}"
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
