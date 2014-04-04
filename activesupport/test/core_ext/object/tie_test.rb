require 'abstract_unit'
require 'active_support/core_ext/object/tie'

class TieTest < ActiveSupport::TestCase
  def test_nil_argument
    assert_equal subject.tie(nil), subject
  end

  def test_nil_and_one_more_argument
    assert_equal subject.tie(nil, 'arg1'), subject
  end

  def test_nil_and_two_more_arguments
    assert_equal subject.tie(nil, 'arg1', 'arg2'), subject
  end

  def test_nil_argument_with_block
    assert_equal subject.tie(nil, &:do_something), subject
  end

  def test_nil_and_two_arguments_with_block
    assert_equal subject.tie(nil, 'arg1', 'arg2', &:do_something), subject
  end

  def test_method_name_argument
    assert_equal subject.tie(:foo), subject.foo
  end

  def test_method_name_and_one_more_argument
    assert_equal subject.tie(:foo, 'arg1'), subject.foo('arg1')
  end

  def test_method_name_and_two_more_arguments
    assert_equal subject.tie(:foo, 'arg1', 'arg2'), subject.foo('arg1', 'arg2')
  end

  def test_method_name_with_block
    assert_equal subject.tie(:foo, &p), subject.foo(&p)
  end

  def test_method_name_and_two_more_arguments_with_block
    assert_equal subject.tie(:foo, 'arg1', 'arg2', &p), subject.foo('arg1', 'arg2', &p)
  end

  def test_yields_self_and_returns_result_if_it_is_not_nil
    assert_equal subject.tie(&:object_id), subject.object_id
  end

  def test_yields_self_and_returns_self_if_result_of_yielding_is_nil
    assert_equal subject.tie{|o| nil }, subject
  end

  def test_yields_self_and_returns_self_if_result_of_yielding_is_false
    assert_equal subject.tie{|o| false }, subject
  end

  def test_no_arguments_and_no_block_given
    assert_raise(ArgumentError) { subject.tie }
  end

private
  def subject
    @subject ||= Object.new.tap do |s|
      def s.foo(*args, &block)
        "Object: #{self} Args: #{args} Block: #{block}"
      end
    end
  end

  def p
    @p ||= proc {}
  end
end
