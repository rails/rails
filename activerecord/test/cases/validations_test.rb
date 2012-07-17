# encoding: utf-8
require "cases/helper"
require 'models/topic'
require 'models/reply'
require 'models/person'
require 'models/developer'
require 'models/parrot'
require 'models/company'

class ValidationsTest < ActiveRecord::TestCase
  fixtures :topics, :developers

  # Most of the tests mess with the validations of Topic, so lets repair it all the time.
  # Other classes we mess with will be dealt with in the specific tests
  repair_validations(Topic)

  def test_error_on_create
    r = WrongReply.new
    r.title = "Wrong Create"
    assert !r.save
    assert r.errors[:title].any?, "A reply with a bad title should mark that attribute as invalid"
    assert_equal ["is Wrong Create"], r.errors[:title], "A reply with a bad content should contain an error"
  end

  def test_error_on_update
    r = WrongReply.new
    r.title = "Bad"
    r.content = "Good"
    assert r.save, "First save should be successful"

    r.title = "Wrong Update"
    assert !r.save, "Second save should fail"

    assert r.errors[:title].any?, "A reply with a bad title should mark that attribute as invalid"
    assert_equal ["is Wrong Update"], r.errors[:title], "A reply with a bad content should contain an error"
  end

  def test_error_on_given_context
    r = WrongReply.new(:title => "Valid title")
    assert !r.valid?(:special_case)
    assert_equal "Invalid", r.errors[:author_name].join

    r.author_name = "secret"
    r.content = "Good"
    assert r.valid?(:special_case)

    r.author_name = nil
    assert !r.save(:context => :special_case)
    assert_equal "Invalid", r.errors[:author_name].join

    r.author_name = "secret"
    assert r.save(:context => :special_case)
  end

  def test_invalid_record_exception
    assert_raise(ActiveRecord::RecordInvalid) { WrongReply.create! }
    assert_raise(ActiveRecord::RecordInvalid) { WrongReply.new.save! }

    begin
      r = WrongReply.new
      r.save!
      flunk
    rescue ActiveRecord::RecordInvalid => invalid
      assert_equal r, invalid.record
    end
  end

  def test_exception_on_create_bang_many
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!([ { "title" => "OK" }, { "title" => "Wrong Create" }])
    end
  end

  def test_exception_on_create_bang_with_block
    assert_raise(ActiveRecord::RecordInvalid) do
      WrongReply.create!({ "title" => "OK" }) do |r|
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

  def test_create_without_validation
    reply = WrongReply.new
    assert !reply.save
    assert reply.save(:validate => false)
  end

  def test_validates_acceptance_of_with_non_existant_table
    Object.const_set :IncorporealModel, Class.new(ActiveRecord::Base)

    assert_nothing_raised ActiveRecord::StatementInvalid do
      IncorporealModel.validates_acceptance_of(:incorporeal_column)
    end
  end

  def test_throw_away_typing
    d = Developer.new("name" => "David", "salary" => "100,000")
    assert !d.valid?
    assert_equal 100, d.salary
    assert_equal "100,000", d.salary_before_type_cast
  end

  def test_validates_acceptance_of_as_database_column
    Topic.validates_acceptance_of(:approved)
    topic = Topic.create("approved" => true)
    assert topic["approved"]
  end

  def test_validators
    assert_equal 1, Parrot.validators.size
    assert_equal 1, Company.validators.size
    assert_equal 1, Parrot.validators_on(:name).size
    assert_equal 1, Company.validators_on(:name).size
  end

end
