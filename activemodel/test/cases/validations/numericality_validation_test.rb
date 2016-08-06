require "cases/helper"

require "models/topic"
require "models/person"

require "bigdecimal"
require "active_support/core_ext/big_decimal"

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
  BIGDECIMAL = BIGDECIMAL_STRINGS.collect! { |bd| BigDecimal.new(bd) }
  JUNK = ["not a number", "42 not a number", "0xdeadbeef", "0xinvalidhex", "0Xdeadbeef", "00-1", "--3", "+-3", "+3-1", "-+019.0", "12.12.13.12", "123\nnot a number"]
  INFINITY = [1.0/0.0]

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
    Topic.validates_numericality_of :approved, only_integer: :condition_is_true_but_its_not

    invalid!(NIL + BLANK + JUNK)
    valid!(FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_integer_only_and_proc_as_value
    Topic.send(:define_method, :allow_only_integers?, lambda { false })
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
    Topic.validates_numericality_of :approved, greater_than: BigDecimal.new("97.18")

    invalid!([-97.18, BigDecimal.new("97.18"), BigDecimal("-97.18")], "must be greater than 97.18")
    valid!([97.18, 98, BigDecimal.new("98")]) # Notice the 97.18 as a float is greater than 97.18 as a BigDecimal due to floating point precision
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
    Topic.validates_numericality_of :approved, greater_than_or_equal_to: BigDecimal.new("97.18")

    invalid!([-97.18, 97.17, 97, BigDecimal.new("97.17"), BigDecimal.new("-97.18")], "must be greater than or equal to 97.18")
    valid!([97.18, 98, BigDecimal.new("97.19")])
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
    Topic.validates_numericality_of :approved, equal_to: BigDecimal.new("97.18")

    invalid!([-97.18, 97.18], "must be equal to 97.18")
    valid!([BigDecimal.new("97.18")])
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
    Topic.validates_numericality_of :approved, less_than: BigDecimal.new("97.18")

    invalid!([97.18, BigDecimal.new("97.18")], "must be less than 97.18")
    valid!([-97.0, 97.0, -97, 97, BigDecimal.new("-97"), BigDecimal.new("97")])
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
    Topic.validates_numericality_of :approved, less_than_or_equal_to: BigDecimal.new("97.18")

    invalid!([97.18, 98], "must be less than or equal to 97.18")
    valid!([-97.18, BigDecimal.new("-97.18"), BigDecimal.new("97.18")])
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

  def test_validates_numericality_with_other_than_using_string_value
    Topic.validates_numericality_of :approved, other_than: 0

    invalid!(["0", "0.0"])
    valid!(["-1", "1.1", "42"])
  end

  def test_validates_numericality_with_proc
    Topic.send(:define_method, :min_approved, lambda { 5 })
    Topic.validates_numericality_of :approved, greater_than_or_equal_to: Proc.new(&:min_approved)

    invalid!([3, 4])
    valid!([5, 6])
  ensure
    Topic.send(:remove_method, :min_approved)
  end

  def test_validates_numericality_with_symbol
    Topic.send(:define_method, :max_approved, lambda { 5 })
    Topic.validates_numericality_of :approved, less_than_or_equal_to: :max_approved

    invalid!([6])
    valid!([4, 5])
  ensure
    Topic.send(:remove_method, :max_approved)
  end

  def test_validates_numericality_with_numeric_message
    Topic.validates_numericality_of :approved, less_than: 4, message: "smaller than %{count}"
    topic = Topic.new("title" => "numeric test", "approved" => 10)

    assert !topic.valid?
    assert_equal ["smaller than 4"], topic.errors[:approved]

    Topic.validates_numericality_of :approved, greater_than: 4, message: "greater than %{count}"
    topic = Topic.new("title" => "numeric test", "approved" => 1)

    assert !topic.valid?
    assert_equal ["greater than 4"], topic.errors[:approved]
  end

  def test_validates_numericality_of_for_ruby_class
    Person.validates_numericality_of :karma, allow_nil: false

    p = Person.new
    p.karma = "Pix"
    assert p.invalid?

    assert_equal ["is not a number"], p.errors[:karma]

    p.karma = "1234"
    assert p.valid?
  ensure
    Person.clear_validators!
  end

  def test_validates_numericality_with_invalid_args
    assert_raise(ArgumentError){ Topic.validates_numericality_of :approved, greater_than_or_equal_to: "foo" }
    assert_raise(ArgumentError){ Topic.validates_numericality_of :approved, less_than_or_equal_to: "foo" }
    assert_raise(ArgumentError){ Topic.validates_numericality_of :approved, greater_than: "foo" }
    assert_raise(ArgumentError){ Topic.validates_numericality_of :approved, less_than: "foo" }
    assert_raise(ArgumentError){ Topic.validates_numericality_of :approved, equal_to: "foo" }
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
