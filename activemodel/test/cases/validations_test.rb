# encoding: utf-8
require 'cases/helper'

require 'models/topic'
require 'models/reply'
require 'models/custom_reader'
require 'models/automobile'

require 'active_support/json'
require 'active_support/xml_mini'

class ValidationsTest < ActiveModel::TestCase

  class CustomStrictValidationException < StandardError; end

  def setup
    Topic._validators.clear
  end

  # Most of the tests mess with the validations of Topic, so lets repair it all the time.
  # Other classes we mess with will be dealt with in the specific tests
  def teardown
    Topic.reset_callbacks(:validate)
  end

  def test_single_field_validation
    r = Reply.new
    r.title = "There's no content!"
    assert r.invalid?, "A reply without content shouldn't be saveable"
    assert r.after_validation_performed, "after_validation callback should be called"

    r.content = "Messa content!"
    assert r.valid?, "A reply with content should be saveable"
    assert r.after_validation_performed, "after_validation callback should be called"
  end

  def test_single_attr_validation_and_error_msg
    r = Reply.new
    r.title = "There's no content!"
    assert r.invalid?
    assert r.errors[:content].any?, "A reply without content should mark that attribute as invalid"
    assert_equal ["is Empty"], r.errors["content"], "A reply without content should contain an error"
    assert_equal 1, r.errors.count
  end

  def test_double_attr_validation_and_error_msg
    r = Reply.new
    assert r.invalid?

    assert r.errors[:title].any?, "A reply without title should mark that attribute as invalid"
    assert_equal ["is Empty"], r.errors["title"], "A reply without title should contain an error"

    assert r.errors[:content].any?, "A reply without content should mark that attribute as invalid"
    assert_equal ["is Empty"], r.errors["content"], "A reply without content should contain an error"

    assert_equal 2, r.errors.count
  end

  def test_single_error_per_attr_iteration
    r = Reply.new
    r.valid?

    errors = r.errors.collect {|attr, messages| [attr.to_s, messages]}

    assert errors.include?(["title", "is Empty"])
    assert errors.include?(["content", "is Empty"])
  end

  def test_multiple_errors_per_attr_iteration_with_full_error_composition
    r = Reply.new
    r.title   = ""
    r.content = ""
    r.valid?

    errors = r.errors.to_a

    assert_equal "Content is Empty", errors[0]
    assert_equal "Title is Empty", errors[1]
    assert_equal 2, r.errors.count
  end

  def test_errors_on_nested_attributes_expands_name
    t = Topic.new
    t.errors["replies.name"] << "can't be blank"
    assert_equal ["Replies name can't be blank"], t.errors.full_messages
  end

  def test_errors_on_base
    r = Reply.new
    r.content = "Mismatch"
    r.valid?
    r.errors.add(:base, "Reply is not dignifying")

    errors = r.errors.to_a.inject([]) { |result, error| result + [error] }

    assert_equal ["Reply is not dignifying"], r.errors[:base]

    assert errors.include?("Title is Empty")
    assert errors.include?("Reply is not dignifying")
    assert_equal 2, r.errors.count
  end

  def test_errors_on_base_with_symbol_message
    r = Reply.new
    r.content = "Mismatch"
    r.valid?
    r.errors.add(:base, :invalid)

    errors = r.errors.to_a.inject([]) { |result, error| result + [error] }

    assert_equal ["is invalid"], r.errors[:base]

    assert errors.include?("Title is Empty")
    assert errors.include?("is invalid")

    assert_equal 2, r.errors.count
  end

  def test_errors_empty_after_errors_on_check
    t = Topic.new
    assert t.errors[:id].empty?
    assert t.errors.empty?
  end

  def test_validates_each
    hits = 0
    Topic.validates_each(:title, :content, [:title, :content]) do |record, attr|
      record.errors.add attr, 'gotcha'
      hits += 1
    end
    t = Topic.new("title" => "valid", "content" => "whatever")
    assert t.invalid?
    assert_equal 4, hits
    assert_equal %w(gotcha gotcha), t.errors[:title]
    assert_equal %w(gotcha gotcha), t.errors[:content]
  end

  def test_validates_each_custom_reader
    hits = 0
    CustomReader.validates_each(:title, :content, [:title, :content]) do |record, attr|
      record.errors.add attr, 'gotcha'
      hits += 1
    end
    t = CustomReader.new("title" => "valid", "content" => "whatever")
    assert t.invalid?
    assert_equal 4, hits
    assert_equal %w(gotcha gotcha), t.errors[:title]
    assert_equal %w(gotcha gotcha), t.errors[:content]
  end

  def test_validate_block
    Topic.validate { errors.add("title", "will never be valid") }
    t = Topic.new("title" => "Title", "content" => "whatever")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["will never be valid"], t.errors["title"]
  end

  def test_validate_block_with_params
    Topic.validate { |topic| topic.errors.add("title", "will never be valid") }
    t = Topic.new("title" => "Title", "content" => "whatever")
    assert t.invalid?
    assert t.errors[:title].any?
    assert_equal ["will never be valid"], t.errors["title"]
  end

  def test_invalid_validator
    Topic.validate :i_dont_exist
    assert_raise(NameError) do
      t = Topic.new
      t.valid?
    end
  end

  def test_errors_conversions
    Topic.validates_presence_of %w(title content)
    t = Topic.new
    assert t.invalid?

    xml = t.errors.to_xml
    assert_match %r{<errors>}, xml
    assert_match %r{<error>Title can't be blank</error>}, xml
    assert_match %r{<error>Content can't be blank</error>}, xml

    hash = {}
    hash[:title] = ["can't be blank"]
    hash[:content] = ["can't be blank"]
    assert_equal t.errors.to_json, hash.to_json
  end

  def test_validation_order
    Topic.validates_presence_of :title
    Topic.validates_length_of :title, :minimum => 2

    t = Topic.new("title" => "")
    assert t.invalid?
    assert_equal "can't be blank", t.errors["title"].first
    Topic.validates_presence_of :title, :author_name
    Topic.validate {errors.add('author_email_address', 'will never be valid')}
    Topic.validates_length_of :title, :content, :minimum => 2

    t = Topic.new :title => ''
    assert t.invalid?

    assert_equal :title, key = t.errors.keys[0]
    assert_equal "can't be blank", t.errors[key][0]
    assert_equal 'is too short (minimum is 2 characters)', t.errors[key][1]
    assert_equal :author_name, key = t.errors.keys[1]
    assert_equal "can't be blank", t.errors[key][0]
    assert_equal :author_email_address, key = t.errors.keys[2]
    assert_equal 'will never be valid', t.errors[key][0]
    assert_equal :content, key = t.errors.keys[3]
    assert_equal 'is too short (minimum is 2 characters)', t.errors[key][0]
  end

  def test_validaton_with_if_and_on
    Topic.validates_presence_of :title, :if => Proc.new{|x| x.author_name = "bad"; true }, :on => :update

    t = Topic.new(:title => "")

    # If block should not fire
    assert t.valid?
    assert t.author_name.nil?

    # If block should fire
    assert t.invalid?(:update)
    assert t.author_name == "bad"
  end

  def test_invalid_should_be_the_opposite_of_valid
    Topic.validates_presence_of :title

    t = Topic.new
    assert t.invalid?
    assert t.errors[:title].any?

    t.title = 'Things are going to change'
    assert !t.invalid?
  end

  def test_validation_with_message_as_proc
    Topic.validates_presence_of(:title, :message => proc { "no blanks here".upcase })

    t = Topic.new
    assert t.invalid?
    assert_equal ["NO BLANKS HERE"], t.errors[:title]
  end

  def test_list_of_validators_for_model
    Topic.validates_presence_of :title
    Topic.validates_length_of :title, :minimum => 2

    assert_equal 2, Topic.validators.count
    assert_equal [:presence, :length], Topic.validators.map(&:kind)
  end

  def test_list_of_validators_on_an_attribute
    Topic.validates_presence_of :title, :content
    Topic.validates_length_of :title, :minimum => 2

    assert_equal 2, Topic.validators_on(:title).count
    assert_equal [:presence, :length], Topic.validators_on(:title).map(&:kind)
    assert_equal 1, Topic.validators_on(:content).count
    assert_equal [:presence], Topic.validators_on(:content).map(&:kind)
  end

  def test_accessing_instance_of_validator_on_an_attribute
    Topic.validates_length_of :title, :minimum => 10
    assert_equal 10, Topic.validators_on(:title).first.options[:minimum]
  end

  def test_list_of_validators_on_multiple_attributes
    Topic.validates :title, :length => { :minimum => 10 }
    Topic.validates :author_name, :presence => true, :format => /a/

    validators = Topic.validators_on(:title, :author_name)

    assert_equal [
      ActiveModel::Validations::FormatValidator,
      ActiveModel::Validations::LengthValidator,
      ActiveModel::Validations::PresenceValidator
    ], validators.map { |v| v.class }.sort_by { |c| c.to_s }
  end

  def test_list_of_validators_will_be_empty_when_empty
    Topic.validates :title, :length => { :minimum => 10 }
    assert_equal [], Topic.validators_on(:author_name)
  end

  def test_validations_on_the_instance_level
    auto = Automobile.new

    assert          auto.invalid?
    assert_equal 2, auto.errors.size

    auto.make  = 'Toyota'
    auto.model = 'Corolla'

    assert auto.valid?
  end

  def test_strict_validation_in_validates
    Topic.validates :title, :strict => true, :presence => true
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_strict_validation_not_fails
    Topic.validates :title, :strict => true, :presence => true
    assert Topic.new(:title => "hello").valid?
  end

  def test_strict_validation_particular_validator
    Topic.validates :title,  :presence => { :strict => true }
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_strict_validation_in_custom_validator_helper
    Topic.validates_presence_of :title, :strict => true
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_strict_validation_custom_exception
    Topic.validates_presence_of :title, :strict => CustomStrictValidationException
    assert_raises CustomStrictValidationException do
      Topic.new.valid?
    end
  end

  def test_validates_with_bang
    Topic.validates! :title,  :presence => true
    assert_raises ActiveModel::StrictValidationFailed do
      Topic.new.valid?
    end
  end

  def test_validates_with_false_hash_value
    Topic.validates :title,  :presence => false
    assert Topic.new.valid?
  end

  def test_strict_validation_error_message
    Topic.validates :title, :strict => true, :presence => true

    exception = assert_raises(ActiveModel::StrictValidationFailed) do
      Topic.new.valid?
    end
    assert_equal "Title can't be blank", exception.message
  end

  def test_does_not_modify_options_argument
    options = { :presence => true }
    Topic.validates :title, options
    assert_equal({ :presence => true }, options)
  end

  def test_dup_validity_is_independent
    Topic.validates_presence_of :title
    topic = Topic.new("title" => "Litterature")
    topic.valid?

    duped = topic.dup
    duped.title = nil
    assert duped.invalid?

    topic.title = nil
    duped.title = 'Mathematics'
    assert topic.invalid?
    assert duped.valid?
  end
end
