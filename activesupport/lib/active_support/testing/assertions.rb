require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

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
      # A lambda or a list of lambdas can be passed in and evaluated:
      #
      #   assert_difference lambda { Article.count }, 2 do
      #     post :create, :article => {...}
      #   end
      #
      #   assert_difference [->{ Article.count }, ->{ Post.count }], 2 do
      #     post :create, :article => {...}
      #   end
      #
      # A error message can be specified.
      #
      #   assert_difference 'Article.count', -1, "An Article should be destroyed" do
      #     post :delete, :id => ...
      #   end
      def assert_difference(expression, difference = 1, message = nil, &block)
        expressions = Array.wrap expression

        exps = expressions.map { |e|
          e.respond_to?(:call) ? e : lambda { eval(e, block.binding) }
        }
        before = exps.map { |e| e.call }

        yield

        expressions.zip(exps).each_with_index do |(code, e), i|
          error  = "#{code.inspect} didn't change by #{difference}"
          error  = "#{message}.\n#{error}" if message
          assert_equal(before[i] + difference, e.call, error)
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
      def assert_no_difference(expression, message = nil, &block)
        assert_difference expression, 0, message, &block
      end

      # Test if an expression is blank. Passes if object.blank? is true.
      #
      #   assert_blank [] # => true
      def assert_blank(object, message=nil)
        message ||= "#{object.inspect} is not blank"
        assert object.blank?, message
      end

      # Test if an expression is not blank. Passes if object.present? is true.
      #
      #   assert_present {:data => 'x' } # => true
      def assert_present(object, message=nil)
        message ||= "#{object.inspect} is blank"
        assert object.present?, message
      end
    end
  end
end
