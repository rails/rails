# frozen_string_literal: true

require "cases/helper"

require "models/topic"
require "models/person"

require "bigdecimal"
require "active_support/core_ext/big_decimal"
require "active_support/core_ext/object/inclusion"

class NumericalityValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  NIL = [nil]
  BLANK = ["", " ", " \t \r \n"]
  BIGDECIMAL_STRINGS = %w(12345678901234567890.1234567890) # 30 significant digits
  FLOAT_STRINGS = %w(0.0 +0.0 -0.0 10.0 10.5 -10.5 -0.0001 -090.1 90.1e1 -90.1e5 -90.1e-5 90e-5)
  INTEGER_STRINGS = %w(0 +0 -0 10 +10 -10 0090 -090)
  FLOATS = [0.0, 10.0, 10.5, -10.5, -0.0001] + FLOAT_STRINGS
  INTEGERS = [0, 10, -10] + INTEGER_STRINGS
  BIGDECIMAL = BIGDECIMAL_STRINGS.collect! { |bd| BigDecimal(bd) }
  JUNK = ["not a number", "42 not a number", "0xdeadbeef", "-0xdeadbeef", "+0xdeadbeef", "0xinvalidhex", "0Xdeadbeef", "00-1", "--3", "+-3", "+3-1", "-+019.0", "12.12.13.12", "123\nnot a number"]
  INFINITY = [1.0 / 0.0]

  def test_default_validates_numericality_of
    Topic.validates_numericality_of :approved
    invalid!(NIL + BLANK + JUNK)
    valid!(FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_nil_allowed
    Topic.validates_numericality_of :approved, allow_nil: true

    invalid!(JUNK + BLANK)
    valid!(NIL + FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_blank_allowed
    Topic.validates_numericality_of :approved, allow_blank: true

    invalid!(JUNK)
    valid!(NIL + BLANK + FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_integer_only
    Topic.validates_numericality_of :approved, only_integer: true

    invalid!(NIL + BLANK + JUNK + FLOATS + BIGDECIMAL + INFINITY)
    valid!(INTEGERS)
  end

  def test_validates_numericality_of_with_integer_only_and_nil_allowed
    Topic.validates_numericality_of :approved, only_integer: true, allow_nil: true

    invalid!(JUNK + BLANK + FLOATS + BIGDECIMAL + INFINITY)
    valid!(NIL + INTEGERS)
  end

  def test_validates_numericality_of_with_integer_only_and_symbol_as_value
    Topic.validates_numericality_of :approved, only_integer: :condition_is_false

    invalid!(NIL + BLANK + JUNK)
    valid!(FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_integer_only_and_proc_as_value
    Topic.define_method(:allow_only_integers?) { false }
    Topic.validates_numericality_of :approved, only_integer: Proc.new(&:allow_only_integers?)

    invalid!(NIL + BLANK + JUNK)
    valid!(FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_with_greater_than
    Topic.validates_numericality_of :approved, greater_than: 10

    invalid!([-10, 10], "must be greater than 10")
    valid!([11])
  end

  def test_validates_numericality_with_greater_than_using_differing_numeric_types
    Topic.validates_numericality_of :approved, greater_than: BigDecimal("97.18")

    invalid!([-97.18, BigDecimal("97.18"), BigDecimal("-97.18")], "must be greater than 97.18")
    valid!([97.19, 98, BigDecimal("98"), BigDecimal("97.19")])
  end

  def test_validates_numericality_with_greater_than_using_string_value
    Topic.validates_numericality_of :approved, greater_than: 10

    invalid!(["-10", "9", "9.9", "10"], "must be greater than 10")
    valid!(["10.1", "11"])
  end

  def test_validates_numericality_with_greater_than_or_equal
    Topic.validates_numericality_of :approved, greater_than_or_equal_to: 10

    invalid!([-9, 9], "must be greater than or equal to 10")
    valid!([10])
  end

  def test_validates_numericality_with_greater_than_or_equal_using_differing_numeric_types
    Topic.validates_numericality_of :approved, greater_than_or_equal_to: BigDecimal("97.18")

    invalid!([-97.18, 97.17, 97, BigDecimal("97.17"), BigDecimal("-97.18")], "must be greater than or equal to 97.18")
    valid!([97.18, 98, BigDecimal("97.19")])
  end

  def test_validates_numericality_with_greater_than_or_equal_using_string_value
    Topic.validates_numericality_of :approved, greater_than_or_equal_to: 10

    invalid!(["-10", "9", "9.9"], "must be greater than or equal to 10")
    valid!(["10", "10.1", "11"])
  end

  def test_validates_numericality_with_equal_to
    Topic.validates_numericality_of :approved, equal_to: 10

    invalid!([-10, 11] + INFINITY, "must be equal to 10")
    valid!([10])
  end

  def test_validates_numericality_with_equal_to_using_differing_numeric_types
    Topic.validates_numericality_of :approved, equal_to: BigDecimal("97.18")

    invalid!([-97.18], "must be equal to 97.18")
    valid!([BigDecimal("97.18")])
  end

  def test_validates_numericality_with_equal_to_using_string_value
    Topic.validates_numericality_of :approved, equal_to: 10

    invalid!(["-10", "9", "9.9", "10.1", "11"], "must be equal to 10")
    valid!(["10"])
  end

  def test_validates_numericality_with_less_than
    Topic.validates_numericality_of :approved, less_than: 10

    invalid!([10], "must be less than 10")
    valid!([-9, 9])
  end

  def test_validates_numericality_with_less_than_using_differing_numeric_types
    Topic.validates_numericality_of :approved, less_than: BigDecimal("97.18")

    invalid!([97.18, BigDecimal("97.18")], "must be less than 97.18")
    valid!([-97.0, 97.0, -97, 97, BigDecimal("-97"), BigDecimal("97")])
  end

  def test_validates_numericality_with_less_than_using_string_value
    Topic.validates_numericality_of :approved, less_than: 10

    invalid!(["10", "10.1", "11"], "must be less than 10")
    valid!(["-10", "9", "9.9"])
  end

  def test_validates_numericality_with_less_than_or_equal_to
    Topic.validates_numericality_of :approved, less_than_or_equal_to: 10

    invalid!([11], "must be less than or equal to 10")
    valid!([-10, 10])
  end

  def test_validates_numericality_with_less_than_or_equal_to_using_differing_numeric_types
    Topic.validates_numericality_of :approved, less_than_or_equal_to: BigDecimal("97.18")

    invalid!([97.19, 98], "must be less than or equal to 97.18")
    valid!([-97.18, BigDecimal("-97.18"), BigDecimal("97.18")])
  end

  def test_validates_numericality_with_less_than_or_equal_using_string_value
    Topic.validates_numericality_of :approved, less_than_or_equal_to: 10

    invalid!(["10.1", "11"], "must be less than or equal to 10")
    valid!(["-10", "9", "9.9", "10"])
  end

  def test_validates_numericality_with_odd
    Topic.validates_numericality_of :approved, odd: true

    invalid!([-2, 2], "must be odd")
    valid!([-1, 1])
  end

  def test_validates_numericality_with_even
    Topic.validates_numericality_of :approved, even: true

    invalid!([-1, 1], "must be even")
    valid!([-2, 2])
  end

  def test_validates_numericality_with_greater_than_less_than_and_even
    Topic.validates_numericality_of :approved, greater_than: 1, less_than: 4, even: true

    invalid!([1, 3, 4])
    valid!([2])
  end

  def test_validates_numericality_with_other_than
    Topic.validates_numericality_of :approved, other_than: 0

    invalid!([0, 0.0])
    valid!([-1, 42])
  end

  def test_validates_numericality_with_in
    Topic.validates_numericality_of :approved, in: 1..3

    invalid!([0, 4])
    valid!([1, 2, 3])
  end

  def test_validates_numericality_with_other_than_using_string_value
    Topic.validates_numericality_of :approved, other_than: 0

    invalid!(["0", "0.0"])
    valid!(["-1", "1.1", "42"])
  end

  def test_validates_numericality_with_proc
    Topic.define_method(:min_approved) { 5 }
    Topic.validates_numericality_of :approved, greater_than_or_equal_to: Proc.new(&:min_approved)

    invalid!([3, 4])
    valid!([5, 6])
  ensure
    Topic.remove_method :min_approved
  end

  def test_validates_numericality_with_symbol
    Topic.define_method(:max_approved) { 5 }
    Topic.validates_numericality_of :approved, less_than_or_equal_to: :max_approved

    invalid!([6])
    valid!([4, 5])
  ensure
    Topic.remove_method :max_approved
  end

  def test_validates_numericality_with_numeric_message
    Topic.validates_numericality_of :approved, less_than: 4, message: "smaller than %{count}"
    topic = Topic.new("title" => "numeric test", "approved" => 10)

    assert_not_predicate topic, :valid?
    assert_equal ["smaller than 4"], topic.errors[:approved]

    Topic.validates_numericality_of :approved, greater_than: 4, message: "greater than %{count}"
    topic = Topic.new("title" => "numeric test", "approved" => 1)

    assert_not_predicate topic, :valid?
    assert_equal ["greater than 4"], topic.errors[:approved]
  end

  def test_validates_numericality_of_for_ruby_class
    Person.validates_numericality_of :karma, allow_nil: false

    p = Person.new
    p.karma = "Pix"
    assert_predicate p, :invalid?

    assert_equal ["is not a number"], p.errors[:karma]

    p.karma = "1234"
    assert_predicate p, :valid?
  ensure
    Person.clear_validators!
  end

  def test_validates_numericality_using_value_before_type_cast_if_possible
    Topic.validates_numericality_of :price

    topic = Topic.new(price: 50)

    assert_equal "$50.00", topic.price
    assert_equal 50, topic.price_before_type_cast
    assert_predicate topic, :valid?
  end

  def test_validates_numericality_with_exponent_number
    base = 10_000_000_000_000_000
    Topic.validates_numericality_of :approved, less_than_or_equal_to: base
    topic = Topic.new
    topic.approved = (base + 1).to_s

    assert_predicate topic, :invalid?
  end

  def test_validates_numericality_with_object_acting_as_numeric
    klass = Class.new do
      def to_f
        123.54
      end
    end

    Topic.validates_numericality_of :price
    topic = Topic.new(price: klass.new)

    assert_predicate topic, :valid?
  end

  def test_validates_numericality_with_invalid_args
    assert_raise(ArgumentError) { Topic.validates_numericality_of :approved, greater_than_or_equal_to: "foo" }
    assert_raise(ArgumentError) { Topic.validates_numericality_of :approved, less_than_or_equal_to: "foo" }
    assert_raise(ArgumentError) { Topic.validates_numericality_of :approved, greater_than: "foo" }
    assert_raise(ArgumentError) { Topic.validates_numericality_of :approved, less_than: "foo" }
    assert_raise(ArgumentError) { Topic.validates_numericality_of :approved, equal_to: "foo" }
  end

  def test_validates_numericality_equality_for_float_and_big_decimal
    Topic.validates_numericality_of :approved, equal_to: BigDecimal("65.6")

    invalid!([Float("65.5"), BigDecimal("65.7")], "must be equal to 65.6")
    valid!([Float("65.6"), BigDecimal("65.6")])
  end

  def test_validates_numericality_with_value_format_as_proc
    Topic.validates_numericality_of :approved, greater_than: 50000, value_format: proc { |value| "50,000.00" }

    invalid!([10], "must be greater than 50,000.00")
  end

  def test_validates_numericality_with_value_format_as_symbol
    Topic.define_method(:value_format) { |value| "50,000.00" }
    Topic.validates_numericality_of :approved, greater_than: 50000, value_format: :value_format

    invalid!([10], "must be greater than 50,000.00")
  ensure
    Topic.remove_method :value_format
  end

  private
    def invalid!(values, error = nil)
      with_each_topic_approved_value(values) do |topic, value|
        assert topic.invalid?, "#{value.inspect} not rejected as a number"
        assert topic.errors[:approved].any?, "FAILED for #{value.inspect}"
        assert_equal error, topic.errors[:approved].first if error
      end
    end

    def valid!(values)
      with_each_topic_approved_value(values) do |topic, value|
        assert topic.valid?, "#{value.inspect} not accepted as a number with validation error: #{topic.errors[:approved].first}"
      end
    end

    def with_each_topic_approved_value(values)
      topic = Topic.new(title: "numeric test", content: "whatever")
      values.each do |value|
        topic.approved = value
        yield topic, value
      end
    end
end
