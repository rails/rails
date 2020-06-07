# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/generated_attribute"

class GeneratedAttributeTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    @old_belongs_to_required_by_default = Rails.application.config.active_record.belongs_to_required_by_default
    Rails.application.config.active_record.belongs_to_required_by_default = true
  end

  def teardown
    Rails.application.config.active_record.belongs_to_required_by_default = @old_belongs_to_required_by_default
  end

  def test_field_type_returns_number_field
    assert_field_type :integer, :number_field
  end

  def test_field_type_returns_text_field
    %w(float decimal string).each do |attribute_type|
      assert_field_type attribute_type, :text_field
    end
  end

  def test_field_type_returns_datetime_select
    %w(datetime timestamp).each do |attribute_type|
      assert_field_type attribute_type, :datetime_select
    end
  end

  def test_field_type_returns_time_select
    assert_field_type :time, :time_select
  end

  def test_field_type_returns_date_select
    assert_field_type :date, :date_select
  end

  def test_field_type_returns_text_area
    assert_field_type :text, :text_area
  end

  def test_field_type_returns_check_box
    assert_field_type :boolean, :check_box
  end

  def test_field_type_returns_rich_text_area
    assert_field_type :rich_text, :rich_text_area
  end

  def test_field_type_returns_file_field
    %w(attachment attachments).each do |attribute_type|
      assert_field_type attribute_type, :file_field
    end
  end

  def test_field_type_with_unknown_type_returns_text_field
    %w(foo bar baz).each do |attribute_type|
      assert_field_type attribute_type, :text_field
    end
  end

  def test_default_value_is_integer
    assert_field_default_value :integer, 1
  end

  def test_default_value_is_float
    assert_field_default_value :float, 1.5
  end

  def test_default_value_is_decimal
    assert_field_default_value :decimal, "9.99"
  end

  def test_default_value_is_datetime
    %w(datetime timestamp time).each do |attribute_type|
      assert_field_default_value attribute_type, Time.now.to_s(:db)
    end
  end

  def test_default_value_is_date
    assert_field_default_value :date, Date.today.to_s(:db)
  end

  def test_default_value_is_string
    assert_field_default_value :string, "MyString"
  end

  def test_default_value_for_type
    att = Rails::Generators::GeneratedAttribute.parse("type:string")
    assert_equal("", att.default)
  end

  def test_default_value_is_text
    assert_field_default_value :text, "MyText"
  end

  def test_default_value_is_boolean
    assert_field_default_value :boolean, false
  end

  def test_default_value_is_nil
    %w(references belongs_to rich_text attachment attachments).each do |attribute_type|
      assert_field_default_value attribute_type, nil
    end
  end

  def test_default_value_is_empty_string
    %w(foo bar baz).each do |attribute_type|
      assert_field_default_value attribute_type, ""
    end
  end

  def test_human_name
    assert_equal(
      "Full name",
      create_generated_attribute(:string, "full_name").human_name
    )
  end

  def test_reference_is_true
    %w(references belongs_to).each do |attribute_type|
      assert_predicate create_generated_attribute(attribute_type), :reference?
    end
  end

  def test_reference_is_false
    %w(foo bar baz).each do |attribute_type|
      assert_not_predicate create_generated_attribute(attribute_type), :reference?
    end
  end

  def test_polymorphic_reference_is_true
    %w(references belongs_to).each do |attribute_type|
      assert_predicate create_generated_attribute("#{attribute_type}{polymorphic}"), :polymorphic?
    end
  end

  def test_polymorphic_reference_is_false
    %w(foo bar baz).each do |attribute_type|
      assert_not_predicate create_generated_attribute("#{attribute_type}{polymorphic}"), :polymorphic?
    end
  end

  def test_blank_type_defaults_to_string
    assert_equal :string, create_generated_attribute(nil, "title").type
    assert_equal :string, create_generated_attribute("", "title").type
  end

  def test_handles_index_names_for_references
    assert_equal "post", create_generated_attribute("string", "post").index_name
    assert_equal "post_id", create_generated_attribute("references", "post").index_name
    assert_equal "post_id", create_generated_attribute("belongs_to", "post").index_name
    assert_equal ["post_id", "post_type"], create_generated_attribute("references{polymorphic}", "post").index_name
  end

  def test_handles_column_names_for_references
    assert_equal "post", create_generated_attribute("string", "post").column_name
    assert_equal "post_id", create_generated_attribute("references", "post").column_name
    assert_equal "post_id", create_generated_attribute("belongs_to", "post").column_name
  end

  def test_parse_required_attribute_with_index
    att = Rails::Generators::GeneratedAttribute.parse("supplier:references:index")
    assert_equal "supplier", att.name
    assert_equal :references, att.type
    assert_predicate att, :has_index?
    assert_predicate att, :required?
  end

  def test_parse_required_attribute_with_index_false_when_belongs_to_required_by_default_global_config_is_false
    Rails.application.config.active_record.belongs_to_required_by_default = false
    att = Rails::Generators::GeneratedAttribute.parse("supplier:references:index")
    assert_not_predicate att, :required?
  end
end
