# frozen_string_literal: true

require "cases/helper"
require "active_model/error"

class ErrorTest < ActiveModel::TestCase
  class Person
    extend ActiveModel::Naming
    def initialize
      @errors = ActiveModel::Errors.new(self)
    end

    attr_accessor :name, :age
    attr_reader   :errors

    def read_attribute_for_validation(attr)
      send(attr)
    end

    def self.human_attribute_name(attr, options = {})
      attr
    end

    def self.lookup_ancestors
      [self]
    end
  end

  class Manager < Person
    def read_attribute_for_validation(attr)
      try(attr)
    end

    def self.i18n_scope
      :activemodel
    end
  end

  def test_initialize
    base = Person.new
    error = ActiveModel::Error.new(base, :name, :too_long, foo: :bar)
    assert_equal base, error.base
    assert_equal :name, error.attribute
    assert_equal :too_long, error.type
    assert_equal({ foo: :bar }, error.options)
  end

  test "initialize without type" do
    error = ActiveModel::Error.new(Person.new, :name)
    assert_equal :invalid, error.type
    assert_equal({}, error.options)
  end

  test "initialize without type but with options" do
    options = { message: "bar" }
    error = ActiveModel::Error.new(Person.new, :name, **options)
    assert_equal(options, error.options)
  end

  # match?

  test "match? handles mixed condition" do
    subject = ActiveModel::Error.new(Person.new, :mineral, :not_enough, count: 2)
    assert_not subject.match?(:mineral, :too_coarse)
    assert subject.match?(:mineral, :not_enough)
    assert subject.match?(:mineral, :not_enough, count: 2)
    assert_not subject.match?(:mineral, :not_enough, count: 1)
  end

  test "match? handles attribute match" do
    subject = ActiveModel::Error.new(Person.new, :mineral, :not_enough, count: 2)
    assert_not subject.match?(:foo)
    assert subject.match?(:mineral)
  end

  test "match? handles error type match" do
    subject = ActiveModel::Error.new(Person.new, :mineral, :not_enough, count: 2)
    assert_not subject.match?(:mineral, :too_coarse)
    assert subject.match?(:mineral, :not_enough)
  end

  test "match? handles extra options match" do
    subject = ActiveModel::Error.new(Person.new, :mineral, :not_enough, count: 2)
    assert_not subject.match?(:mineral, :not_enough, count: 1)
    assert subject.match?(:mineral, :not_enough, count: 2)
  end

  # message

  test "message with type as a symbol" do
    error = ActiveModel::Error.new(Person.new, :name, :blank)
    assert_equal "can't be blank", error.message
  end

  test "message with custom interpolation" do
    subject = ActiveModel::Error.new(Person.new, :name, :inclusion, message: "custom message %{value}", value: "name")
    assert_equal "custom message name", subject.message
  end

  test "message returns plural interpolation" do
    subject = ActiveModel::Error.new(Person.new, :name, :too_long, count: 10)
    assert_equal "is too long (maximum is 10 characters)", subject.message
  end

  test "message returns singular interpolation" do
    subject = ActiveModel::Error.new(Person.new, :name, :too_long, count: 1)
    assert_equal "is too long (maximum is 1 character)", subject.message
  end

  test "message returns count interpolation" do
    subject = ActiveModel::Error.new(Person.new, :name, :too_long, message: "custom message %{count}", count: 10)
    assert_equal "custom message 10", subject.message
  end

  test "message handles lambda in messages and option values, and i18n interpolation" do
    subject = ActiveModel::Error.new(Person.new, :name, :invalid,
      foo: "foo",
      bar: "bar",
      baz: Proc.new { "baz" },
      message: Proc.new { |model, options|
        "%{attribute} %{foo} #{options[:bar]} %{baz}"
      }
    )
    assert_equal "name foo bar baz", subject.message
  end

  test "generate_message works without i18n_scope" do
    person = Person.new
    error = ActiveModel::Error.new(person, :name, :blank)
    assert_not_respond_to Person, :i18n_scope
    assert_nothing_raised {
      error.message
    }
  end

  test "message with type as custom message" do
    error = ActiveModel::Error.new(Person.new, :name, message: "cannot be blank")
    assert_equal "cannot be blank", error.message
  end

  test "message with options[:message] as custom message" do
    error = ActiveModel::Error.new(Person.new, :name, :blank, message: "cannot be blank")
    assert_equal "cannot be blank", error.message
  end

  test "message renders lazily using current locale" do
    error = nil

    I18n.backend.store_translations(:pl, errors: { messages: { invalid: "jest nieprawidłowe" } })

    I18n.with_locale(:en) { error = ActiveModel::Error.new(Person.new, :name, :invalid) }
    I18n.with_locale(:pl) {
      assert_equal "jest nieprawidłowe", error.message
    }
  end

  test "message with type as a symbol and indexed attribute can lookup without index in attribute key" do
    I18n.backend.store_translations(:en, activemodel: { errors: { models: { 'error_test/manager': {
      attributes: { reports: { name: { presence: "must be present" } } } } } } })

    error = ActiveModel::Error.new(Manager.new, :'reports[123].name', :presence)

    assert_equal "must be present", error.message
  end

  test "message uses current locale" do
    I18n.backend.store_translations(:en, errors: { messages: { inadequate: "Inadequate %{attribute} found!" } })
    error = ActiveModel::Error.new(Person.new, :name, :inadequate)
    assert_equal "Inadequate name found!", error.message
  end

  # full_message

  test "full_message returns the given message when attribute is :base" do
    error = ActiveModel::Error.new(Person.new, :base, message: "press the button")
    assert_equal "press the button", error.full_message
  end

  test "full_message returns the given message with the attribute name included" do
    error = ActiveModel::Error.new(Person.new, :name, :blank)
    assert_equal "name can't be blank", error.full_message
  end

  test "full_message uses default format" do
    error = ActiveModel::Error.new(Person.new, :name, message: "can't be blank")

    # Use a locale without errors.format
    I18n.with_locale(:unknown) {
      assert_equal "name can't be blank", error.full_message
    }
  end

  test "equality by base attribute, type and options" do
    person = Person.new

    e1 = ActiveModel::Error.new(person, :name, foo: :bar)
    e2 = ActiveModel::Error.new(person, :name, foo: :bar)
    e2.instance_variable_set(:@_humanized_attribute, "Name")

    assert_equal(e1, e2)
  end

  test "inequality" do
    person = Person.new
    error = ActiveModel::Error.new(person, :name, foo: :bar)

    assert error != ActiveModel::Error.new(person, :name, foo: :baz)
    assert error != ActiveModel::Error.new(person, :name)
    assert error != ActiveModel::Error.new(person, :title, foo: :bar)
    assert error != ActiveModel::Error.new(Person.new, :name, foo: :bar)
  end

  test "comparing against different class would not raise error" do
    person = Person.new
    error = ActiveModel::Error.new(person, :name, foo: :bar)

    assert_not_equal error, person
  end

  test "full_message returns the given message when the attribute contains base" do
    error = ActiveModel::Error.new(Person.new, :"foo.base", "press the button")
    assert_equal "foo.base press the button", error.full_message
  end

  # details

  test "details which ignores callback and message options" do
    person = Person.new
    error = ActiveModel::Error.new(
      person,
      :name,
      :too_short,
      foo: :bar,
      if: :foo,
      unless: :bar,
      on: :baz,
      allow_nil: false,
      allow_blank: false,
      strict: true,
      message: "message"
    )

    assert_equal(
      { error: :too_short, foo: :bar },
      error.details
    )
  end

  test "details which has no raw_type" do
    person = Person.new
    error = ActiveModel::Error.new(person, :name, foo: :bar)

    assert_equal({ error: :invalid, foo: :bar }, error.details)
  end

  test "inspect" do
    person = Person.new
    error = ActiveModel::Error.new(person, :name, :too_short, count: 5)

    assert_match(/\A#<ActiveModel::Error:0x[0-9a-f]+ @attribute=:name, @type=:too_short, @options=#{Regexp.escape({ count: 5 }.inspect)}>\z/, error.inspect)
  end
end
