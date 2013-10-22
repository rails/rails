require 'abstract_unit'
require 'active_support/conditional_options'

class ConditionalOptionsTest < ActiveSupport::TestCase

  def test_without_conditional_keys
    assert ActiveSupport::ConditionalOptions.new.pass?
    assert !ActiveSupport::ConditionalOptions.new.fail?
  end

  def test_with_other_keys
    assert ActiveSupport::ConditionalOptions.new({:foo => 'bar'}).pass?
    assert !ActiveSupport::ConditionalOptions.new({:foo => 'bar'}).fail?
  end

  def test_if_boolean_true
    assert ActiveSupport::ConditionalOptions.new(:if => true).pass?
  end

  def test_if_boolean_false
    assert ActiveSupport::ConditionalOptions.new(:if => false).fail?
  end

  def test_if_boolean_nil
    assert ActiveSupport::ConditionalOptions.new(:if => nil).fail?
  end

  def test_if_boolean_expression
    assert ActiveSupport::ConditionalOptions.new(:if => 'foo' != 'bar').pass?
    assert ActiveSupport::ConditionalOptions.new(:if => 'foo' == 'bar').fail?
  end

  def test_unless_boolean_false
    assert ActiveSupport::ConditionalOptions.new(:unless => false).pass?
  end

  def test_unless_boolean_nil
    assert ActiveSupport::ConditionalOptions.new(:unless => nil).pass?
  end

  def test_unless_boolean_true
    assert ActiveSupport::ConditionalOptions.new(:unless => true).fail?
  end

  def test_unless_boolean_expression
    assert ActiveSupport::ConditionalOptions.new(:unless => 'foo' != 'bar').fail?
    assert ActiveSupport::ConditionalOptions.new(:unless => 'foo' == 'bar').pass?
  end

  def test_if_proc_nil
    assert ActiveSupport::ConditionalOptions.new(:if => lambda { }).fail?
  end

  def test_if_proc_false
    assert ActiveSupport::ConditionalOptions.new(:if => lambda { false }).fail?
  end

  def test_if_proc_expression
    assert ActiveSupport::ConditionalOptions.new(:if => lambda { 'foo' != 'bar' }).pass?
  end

  def test_if_proc_argument
    assert ActiveSupport::ConditionalOptions.new(:if => lambda {|foo| foo != 'bar' }).pass?('foo')
  end

  def test_unless_proc_nil
    assert ActiveSupport::ConditionalOptions.new(:unless => lambda { }).pass?
  end

  def test_unless_proc_false
    assert ActiveSupport::ConditionalOptions.new(:unless => lambda { false }).pass?
  end

  def test_unless_proc_expression
    assert ActiveSupport::ConditionalOptions.new(:unless => lambda { 'foo' != 'bar' }).fail?
  end

  def test_unless_proc_argument
    assert ActiveSupport::ConditionalOptions.new(:unless => lambda {|foo| foo != 'bar' }).fail?('foo')
  end

end
