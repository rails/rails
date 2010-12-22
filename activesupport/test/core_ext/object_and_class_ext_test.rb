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

class ObjectInstanceVariableTest < Test::Unit::TestCase
  def setup
    @source, @dest = Object.new, Object.new
    @source.instance_variable_set(:@bar, 'bar')
    @source.instance_variable_set(:@baz, 'baz')
  end

  def test_instance_variable_names
    assert_equal %w(@bar @baz), @source.instance_variable_names.sort
  end

  def test_copy_instance_variables_from_without_explicit_excludes
    assert_equal [], @dest.instance_variables
    @dest.copy_instance_variables_from(@source)

    assert_equal %w(@bar @baz), @dest.instance_variables.sort.map(&:to_s)
    %w(@bar @baz).each do |name|
      assert_equal @source.instance_variable_get(name).object_id,
                   @dest.instance_variable_get(name).object_id
    end
  end

  def test_copy_instance_variables_from_with_explicit_excludes
    @dest.copy_instance_variables_from(@source, ['@baz'])
    assert !@dest.instance_variable_defined?('@baz')
    assert_equal 'bar', @dest.instance_variable_get('@bar')
  end

  def test_copy_instance_variables_automatically_excludes_protected_instance_variables
    @source.instance_variable_set(:@quux, 'quux')
    class << @source
      def protected_instance_variables
        ['@bar', :@quux]
      end
    end

    @dest.copy_instance_variables_from(@source)
    assert !@dest.instance_variable_defined?('@bar')
    assert !@dest.instance_variable_defined?('@quux')
    assert_equal 'baz', @dest.instance_variable_get('@baz')
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

class ObjectTryTest < Test::Unit::TestCase
  def setup
    @string = "Hello"
  end

  def test_nonexisting_method
    method = :undefined_method
    assert !@string.respond_to?(method)
    assert_raise(NoMethodError) { @string.try(method) }
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
end
