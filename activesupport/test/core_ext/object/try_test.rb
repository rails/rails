require 'abstract_unit'
require 'active_support/core_ext/object'

class ObjectTryTest < ActiveSupport::TestCase
  def setup
    @string = "Hello"
  end

  def test_nonexisting_method
    method = :undefined_method
    assert !@string.respond_to?(method)
    assert_nil @string.try(method)
  end

  def test_nonexisting_method_with_arguments
    method = :undefined_method
    assert !@string.respond_to?(method)
    assert_nil @string.try(method, 'llo', 'y')
  end

  def test_nonexisting_method_bang
    method = :undefined_method
    assert !@string.respond_to?(method)
    assert_raise(NoMethodError) { @string.try!(method) }
  end

  def test_nonexisting_method_with_arguments_bang
    method = :undefined_method
    assert !@string.respond_to?(method)
    assert_raise(NoMethodError) { @string.try!(method, 'llo', 'y') }
  end

  def test_valid_method
    assert_equal 5, @string.try(:size)
  end

  def test_argument_forwarding
    assert_equal 'Hey', @string.try(:sub, 'llo', 'y')
  end

  def test_block_forwarding
    assert_equal 'Hey', @string.try(:sub, 'llo') { |match| 'y' }
  end

  def test_nil_to_type
    assert_nil nil.try(:to_s)
    assert_nil nil.try(:to_i)
  end

  def test_false_try
    assert_equal 'false', false.try(:to_s)
  end

  def test_try_only_block
    assert_equal @string.reverse, @string.try { |s| s.reverse }
  end

  def test_try_only_block_bang
    assert_equal @string.reverse, @string.try! { |s| s.reverse }
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
        'private method'
      end
    end

    assert_raise(NoMethodError) { klass.new.try!(:private_method) }
  end

  def test_try_with_private_method
    klass = Class.new do
      private

      def private_method
        'private method'
      end
    end

    assert_nil klass.new.try(:private_method)
  end
end
