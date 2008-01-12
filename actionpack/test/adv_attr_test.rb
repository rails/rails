require File.dirname(__FILE__) + '/abstract_unit'
require 'action_mailer/adv_attr_accessor'

class AdvAttrTest < Test::Unit::TestCase
  class Person
    include ActionMailer::AdvAttrAccessor
    adv_attr_accessor :name
  end

  def test_adv_attr
    bob = Person.new
    assert_nil bob.name
    bob.name 'Bob'
    assert_equal 'Bob', bob.name

    assert_raise(ArgumentError) {bob.name 'x', 'y'}
  end


end