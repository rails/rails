# frozen_string_literal: true

require "cases/helper"
require "models/numeric_data"

class NumericalityValidationTest < ActiveRecord::TestCase
  def setup
    @model_class = NumericData.dup
  end

  attr_reader :model_class

  def test_column_with_precision
    model_class.validates_numericality_of(
      :unscaled_bank_balance, equal_to: 10_000_000.12
    )

    subject = model_class.new(unscaled_bank_balance: 10_000_000.121)

    assert_predicate subject, :valid?
  end

  def test_column_with_precision_higher_than_double_fig
    model_class.validates_numericality_of(
      :decimal_number_big_precision, equal_to: 10_000_000.3
    )

    subject = model_class.new(decimal_number_big_precision: 10_000_000.3)

    assert_predicate subject, :valid?
  end

  def test_column_with_scale
    model_class.validates_numericality_of(
      :bank_balance, greater_than: 10
    )

    subject = model_class.new(bank_balance: 10.001)

    assert_not_predicate subject, :valid?
  end

  def test_no_column_precision
    model_class.validates_numericality_of(
      :decimal_number, equal_to: 1_000_000_000.123454
    )

    subject = model_class.new(decimal_number: 1_000_000_000.1234545)

    assert_predicate subject, :valid?
  end

  def test_virtual_attribute
    model_class.attribute(:virtual_decimal_number, :decimal)
    model_class.validates_numericality_of(
      :virtual_decimal_number, equal_to: 1_000_000_000.123454
    )

    subject = model_class.new(virtual_decimal_number: 1_000_000_000.1234545)

    assert_predicate subject, :valid?
  end

  def test_on_abstract_class
    abstract_class = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      validates(:bank_balance, numericality: { equal_to: 10_000_000.12 })
    end

    klass = Class.new(abstract_class) do
      def self.table_name
        "numeric_data"
      end

      def self.name
        "MyClass"
      end
    end
    subject = klass.new(bank_balance: 10_000_000.12)

    assert_predicate(subject, :valid?)
  end

  def test_virtual_attribute_with_precision
    model_class.attribute(:virtual_decimal_number, :decimal, precision: 5)
    model_class.validates_numericality_of(
      :virtual_decimal_number, equal_to: 123.45
    )

    subject = model_class.new(virtual_decimal_number: 123.455)

    assert_predicate subject, :valid?
  end

  def test_virtual_attribute_with_scale
    model_class.attribute(:virtual_decimal_number, :decimal, scale: 2)
    model_class.validates_numericality_of(
      :virtual_decimal_number, greater_than: 1
    )

    subject = model_class.new(virtual_decimal_number: 1.001)

    assert_not_predicate subject, :valid?
  end

  def test_virtual_attribute_with_precision_and_scale
    model_class.attribute(:virtual_decimal_number, :decimal, precision: 4, scale: 2)
    model_class.validates_numericality_of(
      :virtual_decimal_number, less_than_or_equal_to: 99.99
    )

    ["99.994", 99.994, BigDecimal("99.994")].each do |raw_value|
      subject = model_class.new(virtual_decimal_number: raw_value)
      assert_equal BigDecimal("99.99"), subject.virtual_decimal_number
      assert_predicate subject, :valid?
    end

    ["99.999", 99.999, BigDecimal("99.999")].each do |raw_value|
      subject = model_class.new(virtual_decimal_number: raw_value)
      assert_equal BigDecimal("100.00"), subject.virtual_decimal_number
      assert_not_predicate subject, :valid?
    end
  end

  def test_aliased_attribute
    model_class.validates_numericality_of(:new_bank_balance, greater_or_equal_than: 0)

    subject = model_class.new(new_bank_balance: "abcd")

    assert_not_predicate subject, :valid?
  end

  def test_allow_nil_works_for_casted_value
    model_class.validates_numericality_of(:bank_balance, greater_than: 0, allow_nil: true)

    subject = model_class.new(bank_balance: "")

    assert_predicate subject, :valid?
  end
end
