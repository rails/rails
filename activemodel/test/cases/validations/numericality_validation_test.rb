# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/developer'
require 'models/person'

class NumericalityValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase
  include ActiveModel::ValidationsRepairHelper

  repair_validations(Topic)

  NIL = [nil]
  BLANK = ["", " ", " \t \r \n"]
  BIGDECIMAL_STRINGS = %w(12345678901234567890.1234567890) # 30 significent digits
  FLOAT_STRINGS = %w(0.0 +0.0 -0.0 10.0 10.5 -10.5 -0.0001 -090.1 90.1e1 -90.1e5 -90.1e-5 90e-5)
  INTEGER_STRINGS = %w(0 +0 -0 10 +10 -10 0090 -090)
  FLOATS = [0.0, 10.0, 10.5, -10.5, -0.0001] + FLOAT_STRINGS
  INTEGERS = [0, 10, -10] + INTEGER_STRINGS
  BIGDECIMAL = BIGDECIMAL_STRINGS.collect! { |bd| BigDecimal.new(bd) }
  JUNK = ["not a number", "42 not a number", "0xdeadbeef", "00-1", "--3", "+-3", "+3-1", "-+019.0", "12.12.13.12", "123\nnot a number"]
  INFINITY = [1.0/0.0]

  def test_default_validates_numericality_of
    Topic.validates_numericality_of :approved
    invalid!(NIL + BLANK + JUNK)
    valid!(FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_nil_allowed
    Topic.validates_numericality_of :approved, :allow_nil => true

    invalid!(JUNK)
    valid!(NIL + BLANK + FLOATS + INTEGERS + BIGDECIMAL + INFINITY)
  end

  def test_validates_numericality_of_with_integer_only
    Topic.validates_numericality_of :approved, :only_integer => true

    invalid!(NIL + BLANK + JUNK + FLOATS + BIGDECIMAL + INFINITY)
    valid!(INTEGERS)
  end

  def test_validates_numericality_of_with_integer_only_and_nil_allowed
    Topic.validates_numericality_of :approved, :only_integer => true, :allow_nil => true

    invalid!(JUNK + FLOATS + BIGDECIMAL + INFINITY)
    valid!(NIL + BLANK + INTEGERS)
  end

  def test_validates_numericality_with_greater_than
    Topic.validates_numericality_of :approved, :greater_than => 10

    invalid!([-10, 10], 'must be greater than 10')
    valid!([11])
  end

  def test_validates_numericality_with_greater_than_or_equal
    Topic.validates_numericality_of :approved, :greater_than_or_equal_to => 10

    invalid!([-9, 9], 'must be greater than or equal to 10')
    valid!([10])
  end

  def test_validates_numericality_with_equal_to
    Topic.validates_numericality_of :approved, :equal_to => 10

    invalid!([-10, 11] + INFINITY, 'must be equal to 10')
    valid!([10])
  end

  def test_validates_numericality_with_less_than
    Topic.validates_numericality_of :approved, :less_than => 10

    invalid!([10], 'must be less than 10')
    valid!([-9, 9])
  end

  def test_validates_numericality_with_less_than_or_equal_to
    Topic.validates_numericality_of :approved, :less_than_or_equal_to => 10

    invalid!([11], 'must be less than or equal to 10')
    valid!([-10, 10])
  end

  def test_validates_numericality_with_odd
    Topic.validates_numericality_of :approved, :odd => true

    invalid!([-2, 2], 'must be odd')
    valid!([-1, 1])
  end

  def test_validates_numericality_with_even
    Topic.validates_numericality_of :approved, :even => true

    invalid!([-1, 1], 'must be even')
    valid!([-2, 2])
  end

  def test_validates_numericality_with_greater_than_less_than_and_even
    Topic.validates_numericality_of :approved, :greater_than => 1, :less_than => 4, :even => true

    invalid!([1, 3, 4])
    valid!([2])
  end

  def test_validates_numericality_with_numeric_message
    Topic.validates_numericality_of :approved, :less_than => 4, :message => "smaller than {{count}}"
    topic = Topic.new("title" => "numeric test", "approved" => 10)

    assert !topic.valid?
    assert_equal ["smaller than 4"], topic.errors[:approved]

    Topic.validates_numericality_of :approved, :greater_than => 4, :message => "greater than {{count}}"
    topic = Topic.new("title" => "numeric test", "approved" => 1)

    assert !topic.valid?
    assert_equal ["greater than 4"], topic.errors[:approved]
  end

  def test_numericality_with_getter_method
    repair_validations(Developer) do
      Developer.validates_numericality_of( :salary )
      developer = Developer.new("name" => "michael", "salary" => nil)
      developer.instance_eval("def salary; read_attribute('salary') ? read_attribute('salary') : 100000; end")
      assert developer.valid?
    end
  end

  def test_numericality_with_allow_nil_and_getter_method
    repair_validations(Developer) do
      Developer.validates_numericality_of( :salary, :allow_nil => true)
      developer = Developer.new("name" => "michael", "salary" => nil)
      developer.instance_eval("def salary; read_attribute('salary') ? read_attribute('salary') : 100000; end")
      assert developer.valid?
    end
  end

  def test_validates_numericality_of_for_ruby_class
    repair_validations(Person) do
      Person.validates_numericality_of :karma, :allow_nil => false

      p = Person.new
      p.karma = "Pix"
      assert p.invalid?

      assert_equal ["is not a number"], p.errors[:karma]

      p.karma = "1234"
      assert p.valid?
    end
  end

  private

  def invalid!(values, error = nil)
    with_each_topic_approved_value(values) do |topic, value|
      assert !topic.valid?, "#{value.inspect} not rejected as a number"
      assert topic.errors[:approved].any?, "FAILED for #{value.inspect}"
      assert_equal error, topic.errors[:approved].first if error
    end
  end

  def valid!(values)
    with_each_topic_approved_value(values) do |topic, value|
      assert topic.valid?, "#{value.inspect} not accepted as a number"
    end
  end

  def with_each_topic_approved_value(values)
    topic = Topic.new(:title => "numeric test", :content => "whatever")
    values.each do |value|
      topic.approved = value
      yield topic, value
    end
  end
end
