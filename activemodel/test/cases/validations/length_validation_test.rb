# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/developer'
require 'models/person'

class LengthValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase
  include ActiveModel::ValidationsRepairHelper

  repair_validations(Topic)

  def test_validates_length_of_with_allow_nil
    Topic.validates_length_of( :title, :is => 5, :allow_nil=>true )

    assert !Topic.create("title" => "ab").valid?
    assert !Topic.create("title" => "").valid?
    assert Topic.create("title" => nil).valid?
    assert Topic.create("title" => "abcde").valid?
  end

  def test_validates_length_of_with_allow_blank
    Topic.validates_length_of( :title, :is => 5, :allow_blank=>true )

    assert !Topic.create("title" => "ab").valid?
    assert Topic.create("title" => "").valid?
    assert Topic.create("title" => nil).valid?
    assert Topic.create("title" => "abcde").valid?
  end

  def test_validates_length_of_using_minimum
    Topic.validates_length_of :title, :minimum => 5

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = "not"
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors[:title]

    t.title = nil
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["is too short (minimum is 5 characters)"], t.errors["title"]
  end

  def test_validates_length_of_using_maximum_should_allow_nil
    Topic.validates_length_of :title, :maximum => 10
    t = Topic.create
    assert t.valid?
  end

  def test_optionally_validates_length_of_using_minimum
    Topic.validates_length_of :title, :minimum => 5, :allow_nil => true

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_maximum
    Topic.validates_length_of :title, :maximum => 5

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = "notvalid"
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:title]

    t.title = ""
    assert t.valid?
  end

  def test_optionally_validates_length_of_using_maximum
    Topic.validates_length_of :title, :maximum => 5, :allow_nil => true

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_within
    Topic.validates_length_of(:title, :content, :within => 3..5)

    t = Topic.new("title" => "a!", "content" => "I'm ooooooooh so very long")
    assert !t.valid?
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:title]
    assert_equal ["is too long (maximum is 5 characters)"], t.errors[:content]

    t.title = nil
    t.content = nil
    assert !t.valid?
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:title]
    assert_equal ["is too short (minimum is 3 characters)"], t.errors[:content]

    t.title = "abe"
    t.content  = "mad"
    assert t.valid?
  end

  def test_validates_length_of_using_within_with_exclusive_range
    Topic.validates_length_of(:title, :within => 4...10)

    t = Topic.new("title" => "9 chars!!")
    assert t.valid?

    t.title = "Now I'm 10"
    assert !t.valid?
    assert_equal ["is too long (maximum is 9 characters)"], t.errors[:title]

    t.title = "Four"
    assert t.valid?
  end

  def test_optionally_validates_length_of_using_within
    Topic.validates_length_of :title, :content, :within => 3..5, :allow_nil => true

    t = Topic.create('title' => 'abc', 'content' => 'abcd')
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_optionally_validates_length_of_using_within_on_create
    Topic.validates_length_of :title, :content, :within => 5..10, :on => :create, :too_long => "my string is too long: {{count}}"

    t = Topic.create("title" => "thisisnotvalid", "content" => "whatever")
    assert !t.save
    assert t.errors[:title].any?
    assert_equal ["my string is too long: 10"], t.errors[:title]

    t.title = "butthisis"
    assert t.save

    t.title = "few"
    assert t.save

    t.content = "andthisislong"
    assert t.save

    t.content = t.title = "iamfine"
    assert t.save
  end

  def test_optionally_validates_length_of_using_within_on_update
    Topic.validates_length_of :title, :content, :within => 5..10, :on => :update, :too_short => "my string is too short: {{count}}"

    t = Topic.create("title" => "vali", "content" => "whatever")
    assert !t.save
    assert t.errors[:title].any?

    t.title = "not"
    assert !t.save
    assert t.errors[:title].any?
    assert_equal ["my string is too short: 5"], t.errors[:title]

    t.title = "valid"
    t.content = "andthisistoolong"
    assert !t.save
    assert t.errors[:content].any?

    t.content = "iamfine"
    assert t.save
  end

  def test_validates_length_of_using_is
    Topic.validates_length_of :title, :is => 5

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = "notvalid"
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["is the wrong length (should be 5 characters)"], t.errors[:title]

    t.title = ""
    assert !t.valid?

    t.title = nil
    assert !t.valid?
  end

  def test_optionally_validates_length_of_using_is
    Topic.validates_length_of :title, :is => 5, :allow_nil => true

    t = Topic.create("title" => "valid", "content" => "whatever")
    assert t.valid?

    t.title = nil
    assert t.valid?
  end

  def test_validates_length_of_using_bignum
    bigmin = 2 ** 30
    bigmax = 2 ** 32
    bigrange = bigmin...bigmax
    assert_nothing_raised do
      Topic.validates_length_of :title, :is => bigmin + 5
      Topic.validates_length_of :title, :within => bigrange
      Topic.validates_length_of :title, :in => bigrange
      Topic.validates_length_of :title, :minimum => bigmin
      Topic.validates_length_of :title, :maximum => bigmax
    end
  end

  def test_validates_length_of_nasty_params
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :minimum=>6, :maximum=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>6, :maximum=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>6, :minimum=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>6, :is=>9) }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :minimum=>"a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :maximum=>"a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :within=>"a") }
    assert_raise(ArgumentError) { Topic.validates_length_of(:title, :is=>"a") }
  end

  def test_validates_length_of_custom_errors_for_minimum_with_message
    Topic.validates_length_of( :title, :minimum=>5, :message=>"boo {{count}}" )
    t = Topic.create("title" => "uhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["boo 5"], t.errors[:title]
  end

  def test_validates_length_of_custom_errors_for_minimum_with_too_short
    Topic.validates_length_of( :title, :minimum=>5, :too_short=>"hoo {{count}}" )
    t = Topic.create("title" => "uhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors[:title]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_message
    Topic.validates_length_of( :title, :maximum=>5, :message=>"boo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["boo 5"], t.errors[:title]
  end

  def test_validates_length_of_custom_errors_for_in
    Topic.validates_length_of(:title, :in => 10..20, :message => "hoo {{count}}")
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["hoo 10"], t.errors["title"]

    t = Topic.create("title" => "uhohuhohuhohuhohuhohuhohuhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["hoo 20"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_maximum_with_too_long
    Topic.validates_length_of( :title, :maximum=>5, :too_long=>"hoo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_message
    Topic.validates_length_of( :title, :is=>5, :message=>"boo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["boo 5"], t.errors["title"]
  end

  def test_validates_length_of_custom_errors_for_is_with_wrong_length
    Topic.validates_length_of( :title, :is=>5, :wrong_length=>"hoo {{count}}" )
    t = Topic.create("title" => "uhohuhoh", "content" => "whatever")
    assert !t.valid?
    assert t.errors[:title].any?
    assert_equal ["hoo 5"], t.errors["title"]
  end

  def test_validates_length_of_using_minimum_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :minimum => 5

      t = Topic.create("title" => "一二三四五", "content" => "whatever")
      assert t.valid?

      t.title = "一二三四"
      assert !t.valid?
      assert t.errors[:title].any?
      assert_equal ["is too short (minimum is 5 characters)"], t.errors["title"]
    end
  end

  def test_validates_length_of_using_maximum_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :maximum => 5

      t = Topic.create("title" => "一二三四五", "content" => "whatever")
      assert t.valid?

      t.title = "一二34五六"
      assert !t.valid?
      assert t.errors[:title].any?
      assert_equal ["is too long (maximum is 5 characters)"], t.errors["title"]
    end
  end

  def test_validates_length_of_using_within_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of(:title, :content, :within => 3..5)

      t = Topic.new("title" => "一二", "content" => "12三四五六七")
      assert !t.valid?
      assert_equal ["is too short (minimum is 3 characters)"], t.errors[:title]
      assert_equal ["is too long (maximum is 5 characters)"], t.errors[:content]
      t.title = "一二三"
      t.content  = "12三"
      assert t.valid?
    end
  end

  def test_optionally_validates_length_of_using_within_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :within => 3..5, :allow_nil => true

      t = Topic.create(:title => "一二三四五")
      assert t.valid?, t.errors.inspect

      t = Topic.create(:title => "一二三")
      assert t.valid?, t.errors.inspect

      t.title = nil
      assert t.valid?, t.errors.inspect
    end
  end

  def test_optionally_validates_length_of_using_within_on_create_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :within => 5..10, :on => :create, :too_long => "長すぎます: {{count}}"

      t = Topic.create("title" => "一二三四五六七八九十A", "content" => "whatever")
      assert !t.save
      assert t.errors[:title].any?
      assert_equal "長すぎます: 10", t.errors[:title].first

      t.title = "一二三四五六七八九"
      assert t.save

      t.title = "一二3"
      assert t.save

      t.content = "一二三四五六七八九十"
      assert t.save

      t.content = t.title = "一二三四五六"
      assert t.save
    end
  end

  def test_optionally_validates_length_of_using_within_on_update_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :within => 5..10, :on => :update, :too_short => "短すぎます: {{count}}"

      t = Topic.create("title" => "一二三4", "content" => "whatever")
      assert !t.save
      assert t.errors[:title].any?

      t.title = "1二三4"
      assert !t.save
      assert t.errors[:title].any?
      assert_equal ["短すぎます: 5"], t.errors[:title]

      t.title = "一二三四五六七八九十A"
      assert !t.save
      assert t.errors[:title].any?

      t.title = "一二345"
      assert t.save
    end
  end

  def test_validates_length_of_using_is_utf8
    with_kcode('UTF8') do
      Topic.validates_length_of :title, :is => 5

      t = Topic.create("title" => "一二345", "content" => "whatever")
      assert t.valid?

      t.title = "一二345六"
      assert !t.valid?
      assert t.errors[:title].any?
      assert_equal ["is the wrong length (should be 5 characters)"], t.errors["title"]
    end
  end

  def test_validates_length_of_with_block
    Topic.validates_length_of :content, :minimum => 5, :too_short=>"Your essay must be at least {{count}} words.",
                                        :tokenizer => lambda {|str| str.scan(/\w+/) }
    t = Topic.create!(:content => "this content should be long enough")
    assert t.valid?

    t.content = "not long enough"
    assert !t.valid?
    assert t.errors[:content].any?
    assert_equal ["Your essay must be at least 5 words."], t.errors[:content]
  end

  def test_validates_length_of_with_custom_too_long_using_quotes
    repair_validations(Developer) do
      Developer.validates_length_of :name, :maximum => 4, :too_long=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Jeffrey"
      assert !d.valid?
      assert_equal ["This string contains 'single' and \"double\" quotes"], d.errors[:name]
    end
  end

  def test_validates_length_of_with_custom_too_short_using_quotes
    repair_validations(Developer) do
      Developer.validates_length_of :name, :minimum => 4, :too_short=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Joe"
      assert !d.valid?
      assert_equal ["This string contains 'single' and \"double\" quotes"], d.errors[:name]
    end
  end

  def test_validates_length_of_with_custom_message_using_quotes
    repair_validations(Developer) do
      Developer.validates_length_of :name, :minimum => 4, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.name = "Joe"
      assert !d.valid?
      assert_equal ["This string contains 'single' and \"double\" quotes"], d.errors[:name]
    end
  end

  def test_validates_length_of_for_ruby_class
    repair_validations(Person) do
      Person.validates_length_of :karma, :minimum => 5

      p = Person.new
      p.karma = "Pix"
      assert p.invalid?

      assert_equal ["is too short (minimum is 5 characters)"], p.errors[:karma]

      p.karma = "The Smiths"
      assert p.valid?
    end
  end
end
