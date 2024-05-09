# frozen_string_literal: true

require "cases/helper"

require "active_support/core_ext/numeric"

class FormatValueTest < ActiveModel::TestCase
  class Validator
    include ActiveModel::Validations
    include ActiveModel::Validations::FormatValue
    attr_accessor :options
  end

  class Record; end

  def setup
    @validator = Validator.new
  end

  def test_format_value_with_proc
    @validator.options = { value_format: Proc.new { |value| value.to_fs(:delimited) } }
    assert_equal "1,000", @validator.format_value(Record.new, 1_000)
  end

  def test_format_value_with_method
    Record.define_method(:value_format) { |value| value.to_fs(:delimited) }
    @validator.options = { value_format: :value_format }
    assert_equal "1,000", @validator.format_value(Record.new, 1_000)
  ensure
    Record.remove_method :value_format
  end

  def test_format_value_with_lambda
    @validator.options = { value_format: -> (value) { value.to_fs(:delimited) } }
    assert_equal "1,000", @validator.format_value(Record.new, 1_000)
  end

  def test_format_value_with_invalid_format
    @validator.options = { value_format: "foo" }
    assert_equal 1_000, @validator.format_value(Record.new, 1_000)
  end
end
