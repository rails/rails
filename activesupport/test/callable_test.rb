# frozen_string_literal: true

module ActiveSupport
  class CallableTest < TestCase
    test "case-equals a proc" do
      assert Callable === Proc.new { }, "should be case-equals"
    end

    test "can be used in a case statement for duck-typed call objects" do
      obj = Struct.new(:call).new

      case obj
      when Callable
        assert true
      else
        assert false
      end
    end
  end
end
