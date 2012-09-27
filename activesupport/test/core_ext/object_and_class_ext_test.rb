require 'abstract_unit'
require 'active_support/time'
require 'active_support/core_ext/object'
require 'active_support/core_ext/class/subclasses'

class ClassA; end
class ClassB < ClassA; end
class ClassC < ClassB; end
class ClassD < ClassA; end

class ClassI; end
class ClassJ < ClassI; end

class ClassK
end
module Nested
  class << self
    def on_const_missing(&callback)
      @on_const_missing = callback
    end
    private
      def const_missing(mod_id)
        @on_const_missing[mod_id] if @on_const_missing
        super
      end
  end
  class ClassL < ClassK
  end
end

class ObjectTests < ActiveSupport::TestCase
  class DuckTime
    def acts_like_time?
      true
    end
  end

  def test_duck_typing
    object = Object.new
    time   = Time.now
    date   = Date.today
    dt     = DateTime.new
    duck   = DuckTime.new

    assert !object.acts_like?(:time)
    assert !object.acts_like?(:date)

    assert time.acts_like?(:time)
    assert !time.acts_like?(:date)

    assert !date.acts_like?(:time)
    assert date.acts_like?(:date)

    assert dt.acts_like?(:time)
    assert dt.acts_like?(:date)

    assert duck.acts_like?(:time)
    assert !duck.acts_like?(:date)
  end
end

class ObjectInstanceVariableTest < ActiveSupport::TestCase
  def setup
    @source, @dest = Object.new, Object.new
    @source.instance_variable_set(:@bar, 'bar')
    @source.instance_variable_set(:@baz, 'baz')
  end

  def test_instance_variable_names
    assert_equal %w(@bar @baz), @source.instance_variable_names.sort
  end

  def test_instance_values
    object = Object.new
    object.instance_variable_set :@a, 1
    object.instance_variable_set :@b, 2
    assert_equal({'a' => 1, 'b' => 2}, object.instance_values)
  end

  def test_instance_exec_passes_arguments_to_block
    assert_equal %w(hello goodbye), 'hello'.instance_exec('goodbye') { |v| [self, v] }
  end

  def test_instance_exec_with_frozen_obj
    assert_equal %w(olleh goodbye), 'hello'.freeze.instance_exec('goodbye') { |v| [reverse, v] }
  end

  def test_instance_exec_nested
    assert_equal %w(goodbye olleh bar), 'hello'.instance_exec('goodbye') { |arg|
      [arg] + instance_exec('bar') { |v| [reverse, v] } }
  end
end

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

  def test_try_only_block_nil
    ran = false
    nil.try { ran = true }
    assert_equal false, ran
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
