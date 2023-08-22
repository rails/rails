# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/generated_attribute"
require "rails/generators/base"

class GeneratedAttributeTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    @old_belongs_to_required_by_default = Rails.application.config.active_record.belongs_to_required_by_default
    Rails.application.config.active_record.belongs_to_required_by_default = true
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
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
      assert_field_type attribute_type, :datetime_field
    end
  end

  def test_field_type_returns_time_select
    assert_field_type :time, :time_field
  end

  def test_field_type_returns_date_select
    assert_field_type :date, :date_field
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

  def test_field_type_with_unknown_type_raises_error
    field_type = :unknown
    e = assert_raise Rails::Generators::Error do
      create_generated_attribute field_type
    end
    message = "Could not generate field 'test' with unknown type 'unknown'"
    assert_match message, e.message
  end

  def test_field_type_with_unknown_index_type_raises_error
    index_type = :unknown
    e = assert_raise Rails::Generators::Error do
      create_generated_attribute "string", "name", index_type
    end
    message = "Could not generate field 'name' with unknown index 'unknown'"
    assert_match message, e.message
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
      assert_field_default_value attribute_type, Time.now.to_fs(:db)
    end
  end

  def test_default_value_is_date
    assert_field_default_value :date, Date.today.to_fs(:db)
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
    %w(digest token).each do |attribute_type|
      assert_field_default_value attribute_type, ""
    end
  end

  def test_human_name
    assert_equal(
      "Full name",
      create_generated_attribute(:string, "full_name").human_name
    )
  end

  def test_size_option_can_be_passed_to_string_text_and_binary
    %w(text binary).each do |attribute_type|
      generated_attribute = create_generated_attribute("#{attribute_type}{medium}")
      assert_equal generated_attribute.attr_options[:size], :medium
    end
  end

  def test_size_option_raises_exception_when_passed_to_invalid_type
    %w(integer string).each do |attribute_type|
      e = assert_raise Rails::Generators::Error do
        create_generated_attribute("#{attribute_type}{medium}")
      end
      message = "Could not generate field 'test' with unknown type '#{attribute_type}{medium}'"
      assert_match message, e.message
    end
  end

  def test_limit_option_can_be_passed_to_string_text_integer_and_binary
    %w(string text binary integer).each do |attribute_type|
      generated_attribute = create_generated_attribute("#{attribute_type}{65535}")
      assert_equal generated_attribute.attr_options[:limit], 65535
    end
  end

  def test_reference_is_true
    %w(references belongs_to).each do |attribute_type|
      assert_predicate create_generated_attribute(attribute_type), :reference?
    end
  end

  def test_reference_is_false
    %w(string text float).each do |attribute_type|
      assert_not_predicate create_generated_attribute(attribute_type), :reference?
    end
  end

  def test_polymorphic_reference_is_true
    %w(references belongs_to).each do |attribute_type|
      assert_predicate create_generated_attribute("#{attribute_type}{polymorphic}"), :polymorphic?
    end
  end

  def test_polymorphic_reference_is_false
    %w(references belongs_to).each do |attribute_type|
      assert_not_predicate create_generated_attribute(attribute_type), :polymorphic?
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

  def test_parse_works_with_adapter_specific_types
    att = Rails::Generators::GeneratedAttribute.parse("document:json")
    assert_equal "document", att.name
    assert_equal :json, att.type
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

  def test_parse_attribute_with_one_option_and_no_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal false, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_no_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal false, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_no_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal false, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_no_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal false, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_one_option_and_plain_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}:index"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_plain_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}:index"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_plain_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}:index"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_plain_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}:index"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({}, att.index_options)
  end

  def test_parse_attribute_with_one_option_and_unique_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}:uniq"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true }, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_unique_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}:uniq"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true }, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_unique_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}:uniq"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true }, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_unique_index
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}:uniq"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true }, att.index_options)
  end

  def test_parse_attribute_with_one_option_and_unique_index_with_one_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}:uniq{name:by_title}"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, name: "by_title" }, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_unique_index_with_one_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}:uniq{algorithm:concurrently}"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, algorithm: "concurrently" }, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_unique_index_with_one_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}:uniq{where:active}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, where: "active" }, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_unique_index_with_one_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}:uniq{using:btree}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, using: "btree" }, att.index_options)
  end

  def test_parse_attribute_with_one_option_and_plain_index_with_multiple_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}:index{unique,name:by_title}"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, name: "by_title" }, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_plain_index_with_multiple_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}:index{unique,algorithm:concurrently}"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, algorithm: "concurrently" }, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_plain_index_with_multiple_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}:index{unique,where:active}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, where: "active" }, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_plain_index_with_multiple_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}:index{unique,using:btree}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ unique: true, using: "btree" }, att.index_options)
  end

  def test_parse_attribute_with_one_option_and_plain_index_with_one_nested_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}:index{length:{title:10}}"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ length: { title: 10 } }, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_plain_index_with_one_nested_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}:index{order:{title:desc}}"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ order: { title: "desc" } }, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_plain_index_with_one_nested_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}:index{using:gist,opclass:{owner_id:gist_trgm_ops}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ using: "gist", opclass: { owner_id: "gist_trgm_ops" } }, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_plain_index_with_one_nested_option
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}:index{length:{owner_type:10}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ length: { owner_type: 10 } }, att.index_options)
  end

  def test_parse_attribute_with_one_option_and_plain_index_with_multiple_nested_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "title:string{null:false}:index{length:{title:10},order:{title:asc}}"
    )
    assert_equal "title", att.name
    assert_equal :string, att.type
    assert_equal({ null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ length: { title: 10 }, order: { title: "asc" } }, att.index_options)
  end

  def test_parse_attribute_with_multiple_options_and_plain_index_with_multiple_nested_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "tags:string{array,default:[],null:false}:index{order:{title:desc},length:{title:15}}"
    )
    assert_equal "tags", att.name
    assert_equal :string, att.type
    assert_equal({ array: true, default: [], null: false }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ order: { title: "desc" }, length: { title: 15 } }, att.index_options)
  end

  def test_parse_attribute_with_one_nested_option_and_plain_index_with_multiple_nested_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users}}:index{using:gist,opclass:{owner_id:gist_trgm_ops},length:{owner_type:10}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ using: "gist", opclass: { owner_id: "gist_trgm_ops" }, length: { owner_type: 10 } }, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_plain_index_with_multiple_nested_options
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key:{table_name:users},polymorphic:{default:User}}:index{length:{owner_type:10},order:{owner_id:desc}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ length: { owner_type: 10 }, order: { owner_id: "desc" } }, att.index_options)
  end

  def test_parse_attribute_with_multiple_nested_options_and_plain_index_with_multiple_nested_options_with_spaces
    att = Rails::Generators::GeneratedAttribute.parse(
      "owner:references{foreign_key: {table_name: users}, polymorphic: {default: User}}:index{length: {owner_type: 10}, order: {owner_id: desc}}"
    )
    assert_equal "owner", att.name
    assert_equal :references, att.type
    assert_equal({ foreign_key: { table_name: "users" }, polymorphic: { default: "User" } }, att.attr_options)
    assert_equal true, att.has_index?
    assert_equal({ length: { owner_type: 10 }, order: { owner_id: "desc" } }, att.index_options)
  end
end
