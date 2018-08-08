# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/array"

class ArrayInquirerTest < ActiveSupport::TestCase
  def setup
    @array_inquirer = ActiveSupport::ArrayInquirer.new([:mobile, :tablet, "api"])
  end

  def test_individual
    assert_predicate @array_inquirer, :mobile?
    assert_predicate @array_inquirer, :tablet?
    assert_not_predicate @array_inquirer, :desktop?
  end

  def test_any
    assert @array_inquirer.any?(:mobile, :desktop)
    assert @array_inquirer.any?(:watch, :tablet)
    assert_not @array_inquirer.any?(:desktop, :watch)
  end

  def test_any_string_symbol_mismatch
    assert @array_inquirer.any?("mobile")
    assert @array_inquirer.any?(:api)
  end

  def test_any_with_block
    assert @array_inquirer.any? { |v| v == :mobile }
    assert_not @array_inquirer.any? { |v| v == :desktop }
  end

  def test_respond_to
    assert_respond_to @array_inquirer, :development?
  end

  def test_inquiry
    result = [:mobile, :tablet, "api"].inquiry

    assert_instance_of ActiveSupport::ArrayInquirer, result
    assert_equal @array_inquirer, result
  end

  def test_respond_to_fallback_to_array_respond_to
    Array.class_eval do
      def respond_to_missing?(name, include_private = false)
        (name == :foo) || super
      end
    end
    arr = ActiveSupport::ArrayInquirer.new([:x])

    assert_respond_to arr, :can_you_hear_me?
    assert_respond_to arr, :foo
    assert_not_respond_to arr, :nope
  ensure
    Array.class_eval do
      undef_method :respond_to_missing?
      def respond_to_missing?(name, include_private = false)
        super
      end
    end
  end
end
