# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object"

class ObjectTryTest < ActiveSupport::TestCase
  def setup
    @string = "Hello"
  end

  def test_nonexisting_method
    method = :undefined_method
    assert_not_respond_to @string, method
    assert_nil @string.try(method)
  end

  def test_nonexisting_method_with_arguments
    method = :undefined_method
    assert_not_respond_to @string, method
    assert_nil @string.try(method, "llo", "y")
  end

  def test_nonexisting_method_bang
    method = :undefined_method
    assert_not_respond_to @string, method
    assert_raise(NoMethodError) { @string.try!(method) }
  end

  def test_nonexisting_method_with_arguments_bang
    method = :undefined_method
    assert_not_respond_to @string, method
    assert_raise(NoMethodError) { @string.try!(method, "llo", "y") }
  end

  def test_valid_method
    assert_equal 5, @string.try(:size)
  end

  def test_argument_forwarding
    assert_equal "Hey", @string.try(:sub, "llo", "y")
  end

  def test_block_forwarding
    assert_equal "Hey", @string.try(:sub, "llo") { |match| "y" }
  end

  def test_nil_to_type
    assert_nil nil.try(:to_s)
    assert_nil nil.try(:to_i)
  end

  def test_false_try
    assert_equal "false", false.try(:to_s)
  end

  def test_try_only_block
    assert_equal @string.reverse, @string.try(&:reverse)
  end

  def test_try_only_block_bang
    assert_equal @string.reverse, @string.try!(&:reverse)
  end

  def test_try_only_block_nil
    ran = false
    nil.try { ran = true }
    assert_equal false, ran
  end

  def test_try_with_instance_eval_block
    assert_equal @string.reverse, @string.try { reverse }
  end

  def test_try_with_instance_eval_block_bang
    assert_equal @string.reverse, @string.try! { reverse }
  end

  def test_try_with_private_method_bang
    klass = Class.new do
      private
        def private_method
          "private method"
        end
    end

    assert_raise(NoMethodError) { klass.new.try!(:private_method) }
  end

  def test_try_with_private_method
    klass = Class.new do
      private
        def private_method
          "private method"
        end
    end

    assert_nil klass.new.try(:private_method)
  end

  class Decorator < SimpleDelegator
    def delegator_method
      "delegator method"
    end

    def reverse
      "overridden reverse"
    end

    private
      def private_delegator_method
        "private delegator method"
      end
  end

  def test_try_with_method_on_delegator
    assert_equal "delegator method", Decorator.new(@string).try(:delegator_method)
  end

  def test_try_with_method_on_delegator_target
    assert_equal 5, Decorator.new(@string).try(:size)
  end

  def test_try_with_overridden_method_on_delegator
    assert_equal "overridden reverse", Decorator.new(@string).try(:reverse)
  end

  def test_try_with_private_method_on_delegator
    assert_nil Decorator.new(@string).try(:private_delegator_method)
  end

  def test_try_with_private_method_on_delegator_bang
    assert_raise(NoMethodError) do
      Decorator.new(@string).try!(:private_delegator_method)
    end
  end

  def test_try_with_private_method_on_delegator_target
    klass = Class.new do
      private
        def private_method
          "private method"
        end
    end

    assert_nil Decorator.new(klass.new).try(:private_method)
  end

  def test_try_with_private_method_on_delegator_target_bang
    klass = Class.new do
      private
        def private_method
          "private method"
        end
    end

    assert_raise(NoMethodError) do
      Decorator.new(klass.new).try!(:private_method)
    end
  end
end
