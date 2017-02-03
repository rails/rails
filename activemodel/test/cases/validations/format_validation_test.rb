require "cases/helper"

require "models/topic"
require "models/person"

class PresenceValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_validate_format
    Topic.validates_format_of(:title, :content, with: /\AValidation\smacros \w+!\z/, message: "is bad data")

    t = Topic.new("title" => "i'm incorrect", "content" => "Validation macros rule!")
    assert t.invalid?, "Shouldn't be valid"
    assert_equal ["is bad data"], t.errors[:title]
    assert t.errors[:content].empty?

    t.title = "Validation macros rule!"

    assert t.valid?
    assert t.errors[:title].empty?

    assert_raise(ArgumentError) { Topic.validates_format_of(:title, :content) }
  end

  def test_validate_format_with_allow_blank
    Topic.validates_format_of(:title, with: /\AValidation\smacros \w+!\z/, allow_blank: true)
    assert Topic.new("title" => "Shouldn't be valid").invalid?
    assert Topic.new("title" => "").valid?
    assert Topic.new("title" => nil).valid?
    assert Topic.new("title" => "Validation macros rule!").valid?
  end

  # testing ticket #3142
  def test_validate_format_numeric
    Topic.validates_format_of(:title, :content, with: /\A[1-9][0-9]*\z/, message: "is bad data")

    t = Topic.new("title" => "72x", "content" => "6789")
    assert t.invalid?, "Shouldn't be valid"

    assert_equal ["is bad data"], t.errors[:title]
    assert t.errors[:content].empty?

    t.title = "-11"
    assert t.invalid?, "Shouldn't be valid"

    t.title = "03"
    assert t.invalid?, "Shouldn't be valid"

    t.title = "z44"
    assert t.invalid?, "Shouldn't be valid"

    t.title = "5v7"
    assert t.invalid?, "Shouldn't be valid"

    t.title = "1"

    assert t.valid?
    assert t.errors[:title].empty?
  end

  def test_validate_format_with_formatted_message
    Topic.validates_format_of(:title, with: /\AValid Title\z/, message: "can't be %{value}")
    t = Topic.new(title: "Invalid title")
    assert t.invalid?
    assert_equal ["can't be Invalid title"], t.errors[:title]
  end

  def test_validate_format_of_with_multiline_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, with: /^Valid Title$/) }
  end

  def test_validate_format_of_with_multiline_regexp_and_option
    assert_nothing_raised do
      Topic.validates_format_of(:title, with: /^Valid Title$/, multiline: true)
    end
  end

  def test_validate_format_with_not_option
    Topic.validates_format_of(:title, without: /foo/, message: "should not contain foo")
    t = Topic.new

    t.title = "foobar"
    t.valid?
    assert_equal ["should not contain foo"], t.errors[:title]

    t.title = "something else"
    t.valid?
    assert_equal [], t.errors[:title]
  end

  def test_validate_format_of_without_any_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title) }
  end

  def test_validates_format_of_with_both_regexps_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, with: /this/, without: /that/) }
  end

  def test_validates_format_of_when_with_isnt_a_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, with: "clearly not a regexp") }
  end

  def test_validates_format_of_when_not_isnt_a_regexp_should_raise_error
    assert_raise(ArgumentError) { Topic.validates_format_of(:title, without: "clearly not a regexp") }
  end

  def test_validates_format_of_with_lambda
    Topic.validates_format_of :content, with: lambda { |topic| topic.title == "digit" ? /\A\d+\Z/ : /\A\S+\Z/ }

    t = Topic.new
    t.title = "digit"
    t.content = "Pixies"
    assert t.invalid?

    t.content = "1234"
    assert t.valid?
  end

  def test_validates_format_of_without_lambda
    Topic.validates_format_of :content, without: lambda { |topic| topic.title == "characters" ? /\A\d+\Z/ : /\A\S+\Z/ }

    t = Topic.new
    t.title = "characters"
    t.content = "1234"
    assert t.invalid?

    t.content = "Pixies"
    assert t.valid?
  end

  def test_validates_format_of_for_ruby_class
    Person.validates_format_of :karma, with: /\A\d+\Z/

    p = Person.new
    p.karma = "Pixies"
    assert p.invalid?

    assert_equal ["is invalid"], p.errors[:karma]

    p.karma = "1234"
    assert p.valid?
  ensure
    Person.clear_validators!
  end
end
