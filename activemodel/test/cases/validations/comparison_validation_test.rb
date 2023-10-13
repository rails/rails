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

    assert_invalid_values([-12, 10], "must be greater than 10")
    assert_valid_values([11])
  end

  def test_validates_comparison_with_greater_than_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, greater_than: date_value

    assert_invalid_values([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      Date.parse("2020-08-02"),
      DateTime.new(2020, 8, 1, 12, 34)], "must be greater than 2020-08-02")
    assert_valid_values([Date.parse("2020-08-03"), DateTime.new(2020, 8, 2, 12, 34)])
  end

  def test_validates_comparison_with_greater_than_using_time
    time_value = Time.at(1596285240)
    Topic.validates_comparison_of :approved, greater_than: time_value

    assert_invalid_values([
      Time.at(1596285240),
      Time.at(1593714600)], "must be greater than #{time_value}")
    assert_valid_values([Time.at(1596371640), Time.at(1596393000)])
  end

  def test_validates_comparison_with_greater_than_using_string
    Topic.validates_comparison_of :approved, greater_than: "cat"

    assert_invalid_values(["ant", "cat"], "must be greater than cat")
    assert_valid_values(["dog", "whale"])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_numeric
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: 10

    assert_invalid_values([-12, 5], "must be greater than or equal to 10")
    assert_valid_values([11, 10])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: date_value

    assert_invalid_values([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34)], "must be greater than or equal to 2020-08-02")
    assert_valid_values([Date.parse("2020-08-03"), DateTime.new(2020, 8, 2, 12, 34), Date.parse("2020-08-02")])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_time
    time_value = Time.at(1596285240)
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: time_value

    assert_invalid_values([
      Time.at(1564662840),
      Time.at(1596285230)], "must be greater than or equal to #{time_value}")
    assert_valid_values([Time.at(1596285240), Time.at(1596285241)])
  end

  def test_validates_comparison_with_greater_than_or_equal_to_using_string
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: "cat"

    assert_invalid_values(["ant"], "must be greater than or equal to cat")
    assert_valid_values(["cat", "dog", "whale"])
  end

  def test_validates_comparison_with_equal_to_using_numeric
    Topic.validates_comparison_of :approved, equal_to: 10

    assert_invalid_values([-12, 5, 11], "must be equal to 10")
    assert_valid_values([10])
  end

  def test_validates_comparison_with_equal_to_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, equal_to: date_value

    assert_invalid_values([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34),
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)], "must be equal to 2020-08-02")
    assert_valid_values([Date.parse("2020-08-02"), DateTime.new(2020, 8, 2, 0, 0)])
  end

  def test_validates_comparison_with_equal_to_using_time
    time_value = Time.at(1596285240)
    Topic.validates_comparison_of :approved, equal_to: time_value

    assert_invalid_values([
      Time.at(1564662840),
      Time.at(1596285230)], "must be equal to #{time_value}")
    assert_valid_values([Time.at(1596285240)])
  end

  def test_validates_comparison_with_equal_to_using_string
    Topic.validates_comparison_of :approved, equal_to: "cat"

    assert_invalid_values(["dog", "whale"], "must be equal to cat")
    assert_valid_values(["cat"])
  end

  def test_validates_comparison_with_less_than_using_numeric
    Topic.validates_comparison_of :approved, less_than: 10

    assert_invalid_values([11, 10], "must be less than 10")
    assert_valid_values([-12, -5, 5])
  end

  def test_validates_comparison_with_less_than_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, less_than: date_value

    assert_invalid_values([
      Date.parse("2020-08-02"),
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)], "must be less than 2020-08-02")
    assert_valid_values([Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34)])
  end

  def test_validates_comparison_with_less_than_using_time
    time_value = Time.at(1596285240)
    Topic.validates_comparison_of :approved, less_than: time_value

    assert_invalid_values([
      Time.at(1596371640),
      Time.at(1596393000)], "must be less than #{time_value}")
    assert_valid_values([Time.at(1596285239), Time.at(1593714600)])
  end

  def test_validates_comparison_with_less_than_using_string
    Topic.validates_comparison_of :approved, less_than: "dog"

    assert_invalid_values(["whale"], "must be less than dog")
    assert_valid_values(["ant", "cat"])
  end

  def test_validates_comparison_with_less_than_or_equal_to_using_numeric
    Topic.validates_comparison_of :approved, less_than_or_equal_to: 10

    assert_invalid_values([12], "must be less than or equal to 10")
    assert_valid_values([-11, 5, 10])
  end

  def test_validates_comparison_with_less_than_or_equal_to_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, less_than_or_equal_to: date_value

    assert_invalid_values([
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)], "must be less than or equal to 2020-08-02")
    assert_valid_values([Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      Date.parse("2020-08-02"),
      DateTime.new(2020, 8, 1, 12, 34)])
  end

  def test_validates_comparison_with_less_than_or_equal_to_using_time
    time_value = Time.at(1596285240)
    Topic.validates_comparison_of :approved, less_than_or_equal_to: time_value

    assert_invalid_values([
      Time.at(1598963640),
      Time.at(1596285241)], "must be less than or equal to #{time_value}")
    assert_valid_values([Time.at(1596285240), Time.at(1596285230)])
  end

  def test_validates_comparison_with_less_than_or_equal_to_using_string
    Topic.validates_comparison_of :approved, less_than_or_equal_to: "dog"

    assert_invalid_values(["whale"], "must be less than or equal to dog")
    assert_valid_values(["ant", "cat", "dog"])
  end

  def test_validates_comparison_with_other_than_using_numeric
    Topic.validates_comparison_of :approved, other_than: 10

    assert_invalid_values([10], "must be other than 10")
    assert_valid_values([-12, 5, 11])
  end

  def test_validates_comparison_with_other_than_using_date
    date_value = Date.parse("2020-08-02")
    Topic.validates_comparison_of :approved, other_than: date_value

    assert_invalid_values([Date.parse("2020-08-02"), DateTime.new(2020, 8, 2, 0, 0)], "must be other than 2020-08-02")
    assert_valid_values([
      Date.parse("2019-08-03"),
      Date.parse("2020-07-03"),
      Date.parse("2020-08-01"),
      DateTime.new(2020, 8, 1, 12, 34),
      Date.parse("2020-08-03"),
      DateTime.new(2020, 8, 2, 12, 34)])
  end

  def test_validates_comparison_with_other_than_using_time
    time_value = Time.at(1596285240)
    Topic.validates_comparison_of :approved, other_than: time_value

    assert_invalid_values([Time.at(1596285240)], "must be other than #{time_value}")
    assert_valid_values([Time.at(1564662840), Time.at(1596285230)])
  end

  def test_validates_comparison_with_other_than_using_string
    Topic.validates_comparison_of :approved, other_than: "whale"

    assert_invalid_values(["whale"], "must be other than whale")
    assert_valid_values(["ant", "cat", "dog"])
  end

  def test_validates_comparison_with_proc
    Topic.define_method(:requested) { Date.new(2020, 8, 1) }
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: Proc.new(&:requested)

    assert_invalid_values([Date.new(2020, 7, 1), Date.new(2019, 7, 1), DateTime.new(2020, 7, 1, 22, 34)], "must be greater than or equal to 2020-08-01")
    assert_valid_values([Date.new(2020, 8, 2), DateTime.new(2021, 8, 1)])
  ensure
    Topic.remove_method :requested
  end

  def test_validates_comparison_with_lambda
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: -> { Date.new(2020, 8, 1) }

    assert_invalid_values([Date.new(2020, 7, 1), Date.new(2019, 7, 1), DateTime.new(2020, 7, 1, 22, 34)], "must be greater than or equal to 2020-08-01")
    assert_valid_values([Date.new(2020, 8, 2), DateTime.new(2021, 8, 1)])
  end

  def test_validates_comparison_with_method
    Topic.define_method(:requested) { Date.new(2020, 8, 1) }
    Topic.validates_comparison_of :approved, greater_than_or_equal_to: :requested

    assert_invalid_values([Date.new(2020, 7, 1), Date.new(2019, 7, 1), DateTime.new(2020, 7, 1, 22, 34)], "must be greater than or equal to 2020-08-01")
    assert_valid_values([Date.new(2020, 8, 2), DateTime.new(2021, 8, 1)])
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

    assert_invalid_values([custom.new(530), custom.new(2325)])
    assert_valid_values([custom.new(575), custom.new(250), custom.new(1999)])
  end

  def test_validates_comparison_with_blank_allowed
    Topic.validates_comparison_of :approved, greater_than: "cat", allow_blank: true

    assert_invalid_values(["ant"])
    assert_valid_values([nil, ""])
  end

  def test_validates_comparison_with_nil_allowed
    Topic.validates_comparison_of :approved, less_than: 100, allow_nil: true

    assert_invalid_values([200])
    assert_valid_values([nil, 50])
  end

  def test_validates_comparison_of_incomparables
    Topic.validates_comparison_of :approved, less_than: "cat"

    assert_invalid_values([12], "comparison of Integer with String failed")
    assert_invalid_values([nil])
    assert_valid_values([])
  end

  def test_validates_comparison_of_multiple_values
    Topic.validates_comparison_of :approved, other_than: 17, greater_than: 13

    assert_invalid_values([12, nil, 17])
    assert_valid_values([15])
  end

  def test_validates_comparison_of_no_options
    error = assert_raises(ArgumentError) do
        Topic.validates_comparison_of(:approved)
      end
    assert_equal "Expected one of :greater_than, :greater_than_or_equal_to, :equal_to," \
                 " :less_than, :less_than_or_equal_to, or :other_than option to be supplied.", error.message
  end

  private
    def assert_invalid_values(values, error = nil)
      with_each_topic_approved_value(values) do |topic, value|
        assert_predicate topic, :invalid?, "#{value.inspect} failed comparison"
        assert_predicate topic.errors[:approved], :any?, "FAILED for #{value.inspect}"
        assert_equal error, topic.errors[:approved].first if error
      end
    end

    def assert_valid_values(values)
      with_each_topic_approved_value(values) do |topic, value|
        assert_predicate topic, :valid?, "#{value.inspect} failed comparison with validation error: #{topic.errors[:approved].first}"
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
