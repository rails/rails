require 'abstract_unit'
require 'action_mailer/adv_attr_accessor'

class AdvAttrTest < ActiveSupport::TestCase
  class Person
    cattr_reader :protected_instance_variables
    @@protected_instance_variables = []

    extend ActionMailer::AdvAttrAccessor
    adv_attr_accessor :name
  end

  def setup
    ActiveSupport::Deprecation.silenced = true
    @person = Person.new
  end

  def teardown
    ActiveSupport::Deprecation.silenced = false
  end

  def test_adv_attr
    assert_nil @person.name
    @person.name 'Bob'
    assert_equal 'Bob', @person.name
  end

  def test_adv_attr_writer
    assert_nil @person.name
    @person.name = 'Bob'
    assert_equal 'Bob', @person.name
  end

  def test_raise_an_error_with_multiple_args
    assert_raise(ArgumentError) { @person.name('x', 'y') }
  end

  def test_ivar_is_added_to_protected_instnace_variables
    assert Person.protected_instance_variables.include?('@name')
  end
end
