# frozen_string_literal: true

require "cases/helper"
require "models/boolean"

class BooleanTest < ActiveRecord::TestCase
  def test_boolean
    b_nil   = Boolean.create!(value: nil)
    b_false = Boolean.create!(value: false)
    b_true  = Boolean.create!(value: true)

    assert_nil Boolean.find(b_nil.id).value
    assert_not_predicate Boolean.find(b_false.id), :value?
    assert_predicate Boolean.find(b_true.id), :value?
  end

  def test_boolean_without_questionmark
    b_true = Boolean.create!(value: true)

    subclass   = Class.new(Boolean).find(b_true.id)
    superclass = Boolean.find(b_true.id)

    assert_equal superclass.read_attribute(:has_fun), subclass.read_attribute(:has_fun)
  end

  def test_boolean_cast_from_string
    b_blank = Boolean.create!(value: "")
    b_false = Boolean.create!(value: "0")
    b_true  = Boolean.create!(value: "1")

    assert_nil Boolean.find(b_blank.id).value
    assert_not_predicate Boolean.find(b_false.id), :value?
    assert_predicate Boolean.find(b_true.id), :value?
  end

  def test_find_by_boolean_string
    b_false = Boolean.create!(value: "false")
    b_true  = Boolean.create!(value: "true")

    assert_equal b_false, Boolean.find_by(value: "false")
    assert_equal b_true, Boolean.find_by(value: "true")
  end

  def test_find_by_falsy_boolean_symbol
    ActiveModel::Type::Boolean::FALSE_VALUES.each do |value|
      b_false = Boolean.create!(value: value)

      assert_not_predicate b_false, :value?
      assert_equal b_false, Boolean.find_by(id: b_false.id, value: value.to_s.to_sym)
    end
  end
end
