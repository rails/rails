# frozen_string_literal: true

require "cases/helper"
require "models/topic"
require "models/reply"
require "models/developer"
require "models/computer"
require "models/parrot"
require "models/company"
require "models/price_estimate"

class ValidationsTest < ActiveRecord::TestCase
  fixtures :topics, :developers

  # Most of the tests mess with the validations of Topic, so lets repair it all the time.
  # Other classes we mess with will be dealt with in the specific tests
  repair_validations(Topic)

  def test_valid_uses_create_context_when_new
    r = WrongReply.new
    r.title = "Wrong Create"
    assert_not_predicate r, :valid?
    assert r.errors[:title].any?, "A reply with a bad title should mark that attribute as invalid"
    assert_equal ["is Wrong Create"], r.errors[:title], "A reply with a bad content should contain an error"
  end

  def test_valid_uses_update_context_when_persisted
    r = WrongReply.new
    r.title = "Bad"
    r.content = "Good"
    assert r.save, "First validation should be successful"

    r.title = "Wrong Update"
    assert_not r.valid?, "Second validation should fail"

    assert r.errors[:title].any?, "A reply with a bad title should mark that attribute as invalid"
    assert_equal ["is Wrong Update"], r.errors[:title], "A reply with a bad content should contain an error"
  end

  def test_valid_using_special_context
    r = WrongReply.new(title: "Valid title")
    assert_not r.valid?(:special_case)
    assert_equal "Invalid", r.errors[:author_name].join

    r.author_name = "secret"
    r.content = "Good"
    assert r.valid?(:special_case)

    r.author_name = nil
    assert_not r.valid?(:special_case)
    assert_equal "Invalid", r.errors[:author_name].join

    r.author_name = "secret"
    assert r.valid?(:special_case)
  end

  def test_invalid_using_multiple_contexts
    r = WrongReply.new(title: "Wrong Create")
    assert r.invalid?([:special_case, :create])
    assert_equal "Invalid", r.errors[:author_name].join
    assert_equal "is Wrong Create", r.errors[:title].join
  end

  def test_validate
    r = WrongReply.new

    r.validate
    assert_empty r.errors[:author_name]

    r.validate(:special_case)
    assert_not_empty r.errors[:author_name]

    r.author_name = "secret"

    r.validate(:special_case)
    assert_empty r.errors[:author_name]
  end

  def test_invalid_record_exception
    assert_raise(ActiveRecord::RecordInvalid) { WrongReply.create! }
    assert_raise(ActiveRecord::RecordInvalid) { WrongReply.new.save! }

    r = WrongReply.new
    invalid = assert_raise ActiveRecord::RecordInvalid do
      r.save!
    end
    assert_equal r, invalid.record
  end

  def test_validate_with_bang
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.new.validate!
    end
  end

  def test_validate_with_bang_and_context
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.new.validate!(:special_case)
    end
    r = WrongReply.new(title: "Valid title", author_name: "secret", content: "Good")
    assert r.validate!(:special_case)
  end

  def test_exception_on_create_bang_many
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!([ { "title" => "OK" }, { "title" => "Wrong Create" }])
    end
  end

  def test_exception_on_create_bang_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!("title" => "OK") do |r|
        r.content = nil
      end
    end
  end

  def test_exception_on_create_bang_many_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!([{ "title" => "OK" }, { "title" => "Wrong Create" }]) do |r|
        r.content = nil
      end
    end
  end

  def test_save_without_validation
    reply = WrongReply.new
    assert_not reply.save
    assert reply.save(validate: false)
  end

  def test_validates_acceptance_of_with_non_existent_table
    Object.const_set :IncorporealModel, Class.new(ActiveRecord::Base)

    assert_nothing_raised do
      IncorporealModel.validates_acceptance_of(:incorporeal_column)
    end
  end

  def test_throw_away_typing
    d = Developer.new("name" => "David", "salary" => "100,000")
    assert_not_predicate d, :valid?
    assert_equal 100, d.salary
    assert_equal "100,000", d.salary_before_type_cast
  end

  def test_validates_acceptance_of_with_undefined_attribute_methods
    klass = Class.new(Topic)
    klass.validates_acceptance_of(:approved)
    topic = klass.new(approved: true)
    klass.undefine_attribute_methods
    assert topic.approved
  end

  def test_validates_acceptance_of_as_database_column
    klass = Class.new(Topic)
    klass.validates_acceptance_of(:approved)
    topic = klass.create("approved" => true)
    assert topic["approved"]
  end

  def test_validators
    assert_equal 1, Parrot.validators.size
    assert_equal 1, Company.validators.size
    assert_equal 1, Parrot.validators_on(:name).size
    assert_equal 1, Company.validators_on(:name).size
  end

  def test_numericality_validation_with_mutation
    klass = Class.new(Topic) do
      attribute :wibble, :string
      validates_numericality_of :wibble, only_integer: true
    end

    topic = klass.new(wibble: "123-4567")
    topic.wibble.gsub!("-", "")

    assert_predicate topic, :valid?
  end

  def test_numericality_validation_checks_against_raw_value
    klass = Class.new(Topic) do
      def self.model_name
        ActiveModel::Name.new(self, nil, "Topic")
      end
      attribute :wibble, :decimal, scale: 2, precision: 9
      validates_numericality_of :wibble, greater_than_or_equal_to: BigDecimal("97.18")
    end

    ["97.179", 97.179, BigDecimal("97.179")].each do |raw_value|
      subject = klass.new(wibble: raw_value)
      assert_equal 97.18.to_d(4), subject.wibble
      assert_predicate subject, :valid?
    end

    ["97.174", 97.174, BigDecimal("97.174")].each do |raw_value|
      subject = klass.new(wibble: raw_value)
      assert_equal 97.17.to_d(4), subject.wibble
      assert_not_predicate subject, :valid?
    end
  end

  def test_numericality_validator_wont_be_affected_by_custom_getter
    price_estimate = PriceEstimate.new(price: 50)

    assert_equal "$50.00", price_estimate.price
    assert_equal 50, price_estimate.price_before_type_cast
    assert_equal 50, price_estimate.read_attribute(:price)

    assert_predicate price_estimate, :price_came_from_user?
    assert_predicate price_estimate, :valid?

    price_estimate.save!

    assert_not_predicate price_estimate, :price_came_from_user?
    assert_predicate price_estimate, :valid?
  end

  def test_acceptance_validator_doesnt_require_db_connection
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "posts"
    end
    klass.reset_column_information

    assert_no_queries do
      klass.validates_acceptance_of(:foo)
    end
  end
end
