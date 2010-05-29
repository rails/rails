require 'generators/generators_test_helper'
require 'rails/generators/generated_attribute'

class GeneratedAttributeTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_field_type_returns_text_field
    %w(integer float decimal string).each do |name|
      assert_field_type name, :text_field
    end
  end

  def test_field_type_returns_datetime_select
    %w(datetime timestamp).each do |name|
      assert_field_type name, :datetime_select
    end
  end

  def test_field_type_returns_time_select
    assert_field_type 'time', :time_select
  end

  def test_field_type_returns_date_select
    assert_field_type 'date', :date_select
  end

  def test_field_type_returns_text_area
    assert_field_type 'text', :text_area
  end

  def test_field_type_returns_check_box
    assert_field_type 'boolean', :check_box
  end

  def test_field_type_with_unknown_type_returns_text_field
    %w(foo bar baz).each do |name|
      assert_field_type name, :text_field
    end
  end
end
