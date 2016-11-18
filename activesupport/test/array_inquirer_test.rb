require "abstract_unit"
require "active_support/core_ext/array"

class ArrayInquirerTest < ActiveSupport::TestCase
  def setup
    @array_inquirer = ActiveSupport::ArrayInquirer.new([:mobile, :tablet, "api"])
  end

  def test_individual
    assert @array_inquirer.mobile?
    assert @array_inquirer.tablet?
    assert_not @array_inquirer.desktop?
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
end
