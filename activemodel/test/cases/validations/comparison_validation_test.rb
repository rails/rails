# frozen_string_literal: true

require "cases/helper"

require "models/topic"
require "models/person"

class ComparisonValidationTest < ActiveModel::TestCase
  def teardown
    Topic.clear_validators!
  end

  def test_validates_comparison_with_greater_than_using_numeric
    Topic.validates_comparison_of :approved, greater_than: 10

    invalid!([-12, 10], "must be greater than 10")
    valid!([11])
  end

  def test_validates_comparison_with_greater_than_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, greater_than: date_value

    invalid!([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      Date.parse("2020-08-02"),
      DateTime.new(2020, 8, 1, 12, 34)], "must be greater than 2020-08-02")
    valid!([Date.parse("2020-08-03"), DateTime.new(2020, 8, 2, 12, 34)])
  end

  def test_validates_comparison_with_greater_than_using_string
    Topic.validates_comparison_of :approved, greater_than: "cat"

    invalid!(["ant", "cat"], "must be greater than cat")
    valid!(["dog", "whale"])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_numeric
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: 10

    invalid!([-12, 5], "must be greater than or equal to 10")
    valid!([11, 10])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_string
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: "cat"

    invalid!(["ant"], "must be greater than or equal to cat")
    valid!(["cat", "dog", "whale"])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: date_value

    invalid!([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34)], "must be greater than or equal to 2020-08-02")
    valid!([Date.parse("2020-08-03"), DateTime.new(2020, 8, 2, 12, 34), Date.parse("2020-08-02")])
  end

  def test_validates_comparison_with_equal_to_using_numeric
    Topic.validates_comparison_of :approved, equal_to: 10

    invalid!([-12, 5, 11], "must be equal to 10")
    valid!([10])
  end

  def test_validates_comparison_with_equal_to_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, equal_to: date_value

    invalid!([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34),
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)], "must be equal to 2020-08-02")
    valid!([Date.parse("2020-08-02"), DateTime.new(2020, 8, 2, 0, 0)])
  end

  def test_validates_comparison_with_less_than_using_numeric
    Topic.validates_comparison_of :approved, less_than: 10

    invalid!([11, 10], "must be less than 10")
    valid!([-12, -5, 5])
  end

  def test_validates_comparison_with_less_than_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, less_than: date_value

    invalid!([
      Date.parse("2020-08-02"),
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)], "must be less than 2020-08-02")
    valid!([Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34)])
  end

  def test_validates_comparison_with_less_than_or_equal_to_using_numeric
    Topic.validates_comparison_of :approved, less_than_or_equal_to: 10

    invalid!([12], "must be less than or equal to 10")
    valid!([-11, 5, 10])
  end

  def test_validates_comparison_with_less_than_or_equal_to_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, less_than_or_equal_to: date_value

    invalid!([
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)], "must be less than or equal to 2020-08-02")
    valid!([Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      Date.parse("2020-08-02"),
      DateTime.new(2020, 8, 1, 12, 34)])
  end

  def test_validates_comparison_with_other_than_using_numeric
    Topic.validates_comparison_of :approved, other_than: 10

    invalid!([10], "must be other than 10")
    valid!([-12, 5, 11])
  end

  def test_validates_comparison_with_other_than_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, other_than: date_value

    invalid!([Date.parse("2020-08-02"), DateTime.new(2020, 8, 2, 0, 0)], "must be other than 2020-08-02")
    valid!([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34),
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)])
  end

  def test_validates_comparison_with_proc
    Topic.define_method(:requested) { Date.new(2020, 8, 1) }
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: Proc.new(&:requested)

    invalid!([Date.new(2020, 7, 1), Date.new(2019, 7, 1), DateTime.new(2020, 7, 1, 22, 34)])
    valid!([Date.new(2020, 8, 2), DateTime.new(2021, 8, 1)])
  ensure
    Topic.remove_method :requested
  end

  def test_validates_comparison_with_method
    Topic.define_method(:requested) { Date.new(2020, 8, 1) }
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: :requested

    invalid!([Date.new(2020, 7, 1), Date.new(2019, 7, 1), DateTime.new(2020, 7, 1, 22, 34)])
    valid!([Date.new(2020, 8, 2), DateTime.new(2021, 8, 1)])
  ensure
    Topic.remove_method :requested
  end

  def test_validates_comparison_with_custom_compare
    custom = Struct.new(:amount) {
      include Comparable

      def <=>(other)
        amount % 100 <=> other.amount % 100
      end
    }
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: custom.new(1150)

    invalid!([custom.new(530), custom.new(2325)])
    valid!([custom.new(575), custom.new(250), custom.new(1999)])
  end

  def test_validates_comparison_with_blank_allowed
    Topic.validates_comparison_of :approved, greater_than: "cat", allow_blank: true

    invalid!(["ant"])
    valid!([nil, ""])
  end

  def test_validates_comparison_with_nil_allowed
    Topic.validates_comparison_of :approved, less_than: 100, allow_nil: true

    invalid!([200])
    valid!([nil, 50])
  end

  def test_validates_comparison_of_incomparables
    Topic.validates_comparison_of :approved, less_than: "cat"

    invalid!([12], "comparison of Integer with String failed")
    invalid!([nil])
    valid!([])
  end

  def test_validates_comparison_of_multiple_values
    Topic.validates_comparison_of :approved, other_than: 17, greater_than: 13

    invalid!([12, nil, 17])
    valid!([15])
  end

  def test_validates_comparison_of_no_options
    error = assert_raises(ArgumentError) do
        Topic.validates_comparison_of(:approved)
      end
    assert_equal "Expected one of :greater_than, :greater_than_or_equal_to, :equal_to," \
                 " :less_than, :less_than_or_equal_to, nor :other_than supplied.", error.message
  end

  private
    def invalid!(values, error = nil)
      with_each_topic_approved_value(values) do |topic, value|
        assert topic.invalid?, "#{value.inspect} failed comparison"
        assert topic.errors[:approved].any?, "FAILED for #{value.inspect}"
        assert_equal error, topic.errors[:approved].first if error
      end
    end

    def valid!(values)
      with_each_topic_approved_value(values) do |topic, value|
        assert topic.valid?, "#{value.inspect} failed comparison with validation error: #{topic.errors[:approved].first}"
      end
    end

    def with_each_topic_approved_value(values)
      topic = Topic.new(title: "comparison test", content: "whatever")
      values.each do |value|
        topic.approved = value
        yield topic, value
      end
    end
end
