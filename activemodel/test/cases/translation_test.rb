require "cases/helper"
require "models/person"

class ActiveModelI18nTests < ActiveModel::TestCase

  def setup
    I18n.backend = I18n::Backend::Simple.new
  end

  def teardown
    I18n.backend.reload!
  end

  def test_translated_model_attributes
    I18n.backend.store_translations "en", activemodel: { attributes: { person: { name: "person name attribute" } } }
    assert_equal "person name attribute", Person.human_attribute_name("name")
  end

  def test_translated_model_attributes_with_default
    I18n.backend.store_translations "en", attributes: { name: "name default attribute" }
    assert_equal "name default attribute", Person.human_attribute_name("name")
  end

  def test_translated_model_attributes_using_default_option
    assert_equal "name default attribute", Person.human_attribute_name("name", default: "name default attribute")
  end

  def test_translated_model_attributes_using_default_option_as_symbol
    I18n.backend.store_translations "en", default_name: "name default attribute"
    assert_equal "name default attribute", Person.human_attribute_name("name", default: :default_name)
  end

  def test_translated_model_attributes_falling_back_to_default
    assert_equal "Name", Person.human_attribute_name("name")
  end

  def test_translated_model_attributes_using_default_option_as_symbol_and_falling_back_to_default
    assert_equal "Name", Person.human_attribute_name("name", default: :default_name)
  end

  def test_translated_model_attributes_with_symbols
    I18n.backend.store_translations "en", activemodel: { attributes: { person: { name: "person name attribute"} } }
    assert_equal "person name attribute", Person.human_attribute_name(:name)
  end

  def test_translated_model_attributes_with_ancestor
    I18n.backend.store_translations "en", activemodel: { attributes: { child: { name: "child name attribute"} } }
    assert_equal "child name attribute", Child.human_attribute_name("name")
  end

  def test_translated_model_attributes_with_ancestors_fallback
    I18n.backend.store_translations "en", activemodel: { attributes: { person: { name: "person name attribute"} } }
    assert_equal "person name attribute", Child.human_attribute_name("name")
  end

  def test_translated_model_attributes_with_attribute_matching_namespaced_model_name
    I18n.backend.store_translations "en", activemodel: { attributes: {
      person: { gender: "person gender"},
      "person/gender": { attribute: "person gender attribute" }
    } }

    assert_equal "person gender", Person.human_attribute_name("gender")
    assert_equal "person gender attribute", Person::Gender.human_attribute_name("attribute")
  end

  def test_translated_deeply_nested_model_attributes
    I18n.backend.store_translations "en", activemodel: { attributes: { "person/contacts/addresses": { street: "Deeply Nested Address Street" } } }
    assert_equal "Deeply Nested Address Street", Person.human_attribute_name("contacts.addresses.street")
  end

  def test_translated_nested_model_attributes
    I18n.backend.store_translations "en", activemodel: { attributes: { "person/addresses": { street: "Person Address Street" } } }
    assert_equal "Person Address Street", Person.human_attribute_name("addresses.street")
  end

  def test_translated_nested_model_attributes_with_namespace_fallback
    I18n.backend.store_translations "en", activemodel: { attributes: { addresses: { street: "Cool Address Street" } } }
    assert_equal "Cool Address Street", Person.human_attribute_name("addresses.street")
  end

  def test_translated_model_names
    I18n.backend.store_translations "en", activemodel: { models: { person: "person model" } }
    assert_equal "person model", Person.model_name.human
  end

  def test_translated_model_names_with_sti
    I18n.backend.store_translations "en", activemodel: { models: { child: "child model" } }
    assert_equal "child model", Child.model_name.human
  end

  def test_translated_model_with_namespace
    I18n.backend.store_translations "en", activemodel: { models: { 'person/gender': "gender model" } }
    assert_equal "gender model", Person::Gender.model_name.human
  end

  def test_translated_model_names_with_ancestors_fallback
    I18n.backend.store_translations "en", activemodel: { models: { person: "person model" } }
    assert_equal "person model", Child.model_name.human
  end

  def test_human_does_not_modify_options
    options = { default: "person model" }
    Person.model_name.human(options)
    assert_equal({ default: "person model" }, options)
  end

  def test_human_attribute_name_does_not_modify_options
    options = { default: "Cool gender" }
    Person.human_attribute_name("gender", options)
    assert_equal({ default: "Cool gender" }, options)
  end
end

