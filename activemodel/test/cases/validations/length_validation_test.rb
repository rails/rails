# frozen_string_literal: true

require "cases/helper"

require "models/topic"
require "models/person"

class LengthValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_validates_length_of_with_allow_nil
    Topic.validates_length_of(:title, is: 5, allow_nil: true)

    assert_predicate Topic.new("title" => "ab"), :invalid?
    assert_predicate Topic.new("title" => ""), :invalid?
    assert_predicate Topic.new("title" => nil), :valid?
    assert_predicate Topic.new("title" => "abcde"), :valid?
  end

  def test_validates_length_of_with_allow_blank
    Topic.validates_length_of(:title, is: 5, allow_blank: true)

    assert_predicate Topic.new("title" => "ab"), :invalid?
    assert_predicate Topic.new("title" => ""), :valid?
    assert_predicate Topic.new("title" => nil), :valid?
    assert_predicate Topic.new("title" => "abcde"), :valid?
  end

  def test_validates_length_of_using_minimum
    Topic.validates_length_of :title, minimum: 5

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "not"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors[:title]

    t.title = nil
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors["title"]
  end

  def test_validates_length_of_using_maximum_should_allow_nil
    Topic.validates_length_of :title, maximum: 10
    t = Topic.new
    assert_predicate t, :valid?
  end

  def test_optionally_validates_length_of_using_minimum
    Topic.validates_length_of :title, minimum: 5, allow_nil: true

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = nil
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_maximum
    Topic.validates_length_of :title, maximum: 5

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "notvalid"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert_predicate t, :valid?
  end

  def test_optionally_validates_length_of_using_maximum
    Topic.validates_length_of :title, maximum: 5, allow_nil: true

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = nil
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_within
    Topic.validates_length_of(:title, :content, within: 3..5)

    t = Topic.new("title" => "a!", "content" => "I'm ooooooooh so very long")
    assert_predicate t, :invalid?
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:title]
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:content]

    t.title = nil
    t.content = nil
    assert_predicate t, :invalid?
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:title]
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:content]

    t.title = "abe"
    t.content = "mad"
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_within_with_exclusive_range
    Topic.validates_length_of(:title, within: 4...10)

    t = Topic.new("title" => "9 chars!!")
    assert_predicate t, :valid?

    t.title = "Now I'm 10"
    assert_predicate t, :invalid?
    assert_equal ["is too long (maximum is 9 characters)"], t.errors[:title]

    t.title = "Four"
    assert_predicate t, :valid?
  end

  def test_optionally_validates_length_of_using_within
    Topic.validates_length_of :title, :content, within: 3..5, allow_nil: true

    t = Topic.new("title" => "abc", "content" => "abcd")
    assert_predicate t, :valid?

    t.title = nil
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_is
    Topic.validates_length_of :title, is: 5

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "notvalid"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is the wrong length (should be 5 characters)"], t.errors[:title]

    t.title = ""
    assert_predicate t, :invalid?

    t.title = nil
    assert_predicate t, :invalid?
  end

  def test_optionally_validates_length_of_using_is
    Topic.validates_length_of :title, is: 5, allow_nil: true

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = nil
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_bignum
    bigmin = 2**30
    bigmax = 2**32
    bigrange = bigmin...bigmax
    assert_nothing_raised do
      Topic.validates_length_of :title, is: bigmin + 5
      Topic.validates_length_of :title, within: bigrange
      Topic.validates_length_of :title, in: bigrange
      Topic.validates_length_of :title, minimum: bigmin
      Topic.validates_length_of :title, maximum: bigmax
    end
  end

  def test_validates_length_of_nasty_params
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, is: -6) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, within: 6) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, minimum: "a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, maximum: "a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, within: "a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, is: "a") }
  end

  def test_validates_length_of_custom_errors_for_minimum_with_message
    Topic.validates_length_of(:title, minimum: 5, message: "boo %{count}")
    t = Topic.new("title" => "uhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["boo 5"], t.errors[:title]
  end

  def test_validates_length_of_custom_errors_for_minimum_with_too_short
    Topic.validates_length_of(:title, minimum: 5, too_short: "hoo %{count}")
    t = Topic.new("title" => "uhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["hoo 5"], t.errors[:title]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_message
    Topic.validates_length_of(:title, maximum: 5, message: "boo %{count}")
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["boo 5"], t.errors[:title]
  end

  def test_validates_length_of_custom_errors_for_in
    Topic.validates_length_of(:title, in: 10..20, message: "hoo %{count}")
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["hoo 10"], t.errors["title"]

    t = Topic.new("title" => "uhohuhohuhohuhohuhohuhohuhohuhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["hoo 20"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_too_long
    Topic.validates_length_of(:title, maximum: 5, too_long: "hoo %{count}")
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_both_too_short_and_too_long
    Topic.validates_length_of :title, minimum: 3, maximum: 5, too_short: "too short", too_long: "too long"

    t = Topic.new(title: "a")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["too short"], t.errors["title"]

    t = Topic.new(title: "aaaaaa")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["too long"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_message
    Topic.validates_length_of(:title, is: 5, message: "boo %{count}")
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["boo 5"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_wrong_length
    Topic.validates_length_of(:title, is: 5, wrong_length: "hoo %{count}")
    t = Topic.new("title" => "uhohuhoh", "content" => "whatever")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_validates_length_of_using_minimum_utf8
    Topic.validates_length_of :title, minimum: 5

    t = Topic.new("title" => "一二三四五", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "一二三四"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors["title"]
  end

  def test_validates_length_of_using_maximum_utf8
    Topic.validates_length_of :title, maximum: 5

    t = Topic.new("title" => "一二三四五", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "一二34五六"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too long (maximum is 5 characters)"], t.errors["title"]
  end

  def test_validates_length_of_using_within_utf8
    Topic.validates_length_of(:title, :content, within: 3..5)

    t = Topic.new("title" => "一二", "content" => "12三四五六七")
    assert_predicate t, :invalid?
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:title]
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:content]
    t.title = "一二三"
    t.content = "12三"
    assert_predicate t, :valid?
  end

  def test_optionally_validates_length_of_using_within_utf8
    Topic.validates_length_of :title, within: 3..5, allow_nil: true

    t = Topic.new(title: "一二三四五")
    assert t.valid?, t.errors.inspect

    t = Topic.new(title: "一二三")
    assert t.valid?, t.errors.inspect

    t.title = nil
    assert t.valid?, t.errors.inspect
  end

  def test_validates_length_of_using_is_utf8
    Topic.validates_length_of :title, is: 5

    t = Topic.new("title" => "一二345", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "一二345六"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is the wrong length (should be 5 characters)"], t.errors["title"]
  end

  def test_validates_length_of_for_integer
    Topic.validates_length_of(:approved, is: 4)

    t = Topic.new("title" => "uhohuhoh", "content" => "whatever", approved: 1)
    assert_predicate t, :invalid?
    assert_predicate t.errors[:approved], :any?

    t = Topic.new("title" => "uhohuhoh", "content" => "whatever", approved: 1234)
    assert_predicate t, :valid?
  end

  def test_validates_length_of_for_ruby_class
    Person.validates_length_of :karma, minimum: 5

    p = Person.new
    p.karma = "Pix"
    assert_predicate p, :invalid?

    assert_equal ["is too short (minimum is 5 characters)"], p.errors[:karma]

    p.karma = "The Smiths"
    assert_predicate p, :valid?
  ensure
    Person.clear_validators!
  end

  def test_validates_length_of_for_infinite_maxima
    Topic.validates_length_of(:title, within: 5..Float::INFINITY)

    t = Topic.new("title" => "1234")
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?

    t.title = "12345"
    assert_predicate t, :valid?

    Topic.validates_length_of(:author_name, maximum: Float::INFINITY)

    assert_predicate t, :valid?

    t.author_name = "A very long author name that should still be valid." * 100
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_maximum_should_not_allow_nil_when_nil_not_allowed
    Topic.validates_length_of :title, maximum: 10, allow_nil: false
    t = Topic.new
    assert_predicate t, :invalid?
  end

  def test_validates_length_of_using_maximum_should_not_allow_nil_and_empty_string_when_blank_not_allowed
    Topic.validates_length_of :title, maximum: 10, allow_blank: false
    t = Topic.new
    assert_predicate t, :invalid?

    t.title = ""
    assert_predicate t, :invalid?
  end

  def test_validates_length_of_using_both_minimum_and_maximum_should_not_allow_nil
    Topic.validates_length_of :title, minimum: 5, maximum: 10
    t = Topic.new
    assert_predicate t, :invalid?
  end

  def test_validates_length_of_using_minimum_0_should_allow_nil
    Topic.validates_length_of :title, minimum: 0
    t = Topic.new
    assert_predicate t, :invalid?

    t.title = ""
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_is_0_should_not_allow_nil
    Topic.validates_length_of :title, is: 0
    t = Topic.new
    assert_predicate t, :invalid?

    t.title = ""
    assert_predicate t, :valid?
  end

  def test_validates_with_diff_in_option
    Topic.validates_length_of(:title, is: 5)
    Topic.validates_length_of(:title, is: 5, if: Proc.new { false })

    assert_predicate Topic.new("title" => "david"), :valid?
    assert_predicate Topic.new("title" => "david2"), :invalid?
  end

  def test_validates_length_of_using_symbol_as_maximum
    Topic.validates_length_of :title, maximum: :five

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "notvalid"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_proc_as_maximum
    Topic.validates_length_of :title, maximum: ->(model) { 5 }

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "notvalid"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_proc_as_maximum_with_model_method
    Topic.define_method(:max_title_length) { 5 }
    Topic.validates_length_of :title, maximum: Proc.new(&:max_title_length)

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "notvalid"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert_predicate t, :valid?
  end

  def test_validates_length_of_using_proc_as_minimum_nil_with_instance_variable
    Topic.define_method(:min_title_length) { 5 }
    Topic.validates_length_of :title, minimum: Proc.new(&:min_title_length)

    t = Topic.new("title" => "valid", "content" => "whatever")
    assert_predicate t, :valid?

    t.title = "not"
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors[:title]

    t.title = nil
    assert_predicate t, :invalid?
    assert_predicate t.errors[:title], :any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors[:title]
  end
end
