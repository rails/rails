require 'cases/helper'
require 'models/topic'
require 'models/person'

class InstanceValidationTest < ActiveModel::TestCase
  teardown do
    Topic.clear_validators!
    Person.clear_validators!
  end

  def test_validates_instance_of_single_value
    Topic.validates_instance_of(:title, is_a: String)
    t = Topic.new
    t.title = 1000
    assert t.invalid?
    assert_equal ["not instance of String"], t.errors[:title]
  end

  def test_validates_instance_of_in
    Topic.validates_instance_of(:author_name, in: [String, Person])
    t = Topic.new
    t.author_name = 1000
    assert t.invalid?
    assert_equal ["not instance among [String, Person]"], t.errors[:author_name]

    t.author_name = "Bingo!"
    assert t.valid?

    t.author_name = Person.new
    assert t.valid?
  end

end
