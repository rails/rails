require 'active_support/core_ext/object/send_if_responds_to'

class SendIfRespondsToTest < ActiveSupport::TestCase
  def test_should_send_method_if_responds_to
    klass = Class.new do
      def foo(a, b)
        "#{a}#{b}"
      end
    end

    assert_equal "hello", klass.new.send_if_responds_to(:foo, "he", "llo")
    assert_equal 0, nil.send_if_responds_to(:to_i)
  end

  def test_should_return_false_if_does_not_respond_to
    assert_equal Object.new.send_if_responds_to(:not_existing), false
  end

end
