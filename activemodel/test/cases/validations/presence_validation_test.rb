require "cases/helper"

require "models/topic"
require "models/person"
require "models/custom_reader"

class PresenceValidationTest < ActiveModel::TestCase
  teardown do
    Topic.clear_validators!
    Person.clear_validators!
    CustomReader.clear_validators!
  end

  def test_validate_presences
    Topic.validates_presence_of(:title, :content)

    t = Topic.new
    assert t.invalid?
    assert_equal ["can't be blank"], t.errors[:title]
    assert_equal ["can't be blank"], t.errors[:content]

    t.title = "something"
    t.content = "   "

    assert t.invalid?
    assert_equal ["can't be blank"], t.errors[:content]

    t.content = "like stuff"

    assert t.valid?
  end

  def test_accepts_array_arguments
    Topic.validates_presence_of %w(title content)
    t = Topic.new
    assert t.invalid?
    assert_equal ["can't be blank"], t.errors[:title]
    assert_equal ["can't be blank"], t.errors[:content]
  end

  def test_validates_acceptance_of_with_custom_error_using_quotes
    Person.validates_presence_of :karma, message: "This string contains 'single' and \"double\" quotes"
    p = Person.new
    assert p.invalid?
    assert_equal "This string contains 'single' and \"double\" quotes", p.errors[:karma].last
  end

  def test_validates_presence_of_for_ruby_class
    Person.validates_presence_of :karma

    p = Person.new
    assert p.invalid?

    assert_equal ["can't be blank"], p.errors[:karma]

    p.karma = "Cold"
    assert p.valid?
  end

  def test_validates_presence_of_for_ruby_class_with_custom_reader
    CustomReader.validates_presence_of :karma

    p = CustomReader.new
    assert p.invalid?

    assert_equal ["can't be blank"], p.errors[:karma]

    p[:karma] = "Cold"
    assert p.valid?
  end

  def test_validates_presence_of_with_allow_nil_option
    Topic.validates_presence_of(:title, allow_nil: true)

    t = Topic.new(title: "something")
    assert t.valid?, t.errors.full_messages

    t.title = ""
    assert t.invalid?
    assert_equal ["can't be blank"], t.errors[:title]

    t.title = "  "
    assert t.invalid?, t.errors.full_messages
    assert_equal ["can't be blank"], t.errors[:title]

    t.title = nil
    assert t.valid?, t.errors.full_messages
  end

  def test_validates_presence_of_with_allow_blank_option
    Topic.validates_presence_of(:title, allow_blank: true)

    t = Topic.new(title: "something")
    assert t.valid?, t.errors.full_messages

    t.title = ""
    assert t.valid?, t.errors.full_messages

    t.title = "  "
    assert t.valid?, t.errors.full_messages

    t.title = nil
    assert t.valid?, t.errors.full_messages
  end
end
