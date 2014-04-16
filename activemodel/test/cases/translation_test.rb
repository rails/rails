require 'cases/helper'
require 'models/person'

class ActiveModelI18nTests < ActiveModel::TestCase

  def setup
    I18n.backend = I18n::Backend::Simple.new
  end

  def teardown
    I18n.backend.reload!
  end

  test "translated model attributes" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { person: { name: 'person name attribute' } } }
    assert_equal 'person name attribute', Person.human_attribute_name('name')
  end

  test "translated model attributes with default" do
    I18n.backend.store_translations 'en', attributes: { name: 'name default attribute' }
    assert_equal 'name default attribute', Person.human_attribute_name('name')
  end

  test "translated model attributes using default option" do
    assert_equal 'name default attribute', Person.human_attribute_name('name', default: "name default attribute")
  end

  test "translated model attributes using default option as symbol" do
    I18n.backend.store_translations 'en', default_name: 'name default attribute'
    assert_equal 'name default attribute', Person.human_attribute_name('name', default: :default_name)
  end

  test "translated model attributes falling back to default" do
    assert_equal 'Name', Person.human_attribute_name('name')
  end

  test "translated model attributes using default option as symbol and falling back to default" do
    assert_equal 'Name', Person.human_attribute_name('name', default: :default_name)
  end

  test "translated model attributes with symbols" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { person: { name: 'person name attribute'} } }
    assert_equal 'person name attribute', Person.human_attribute_name(:name)
  end

  test "translated model attributes with ancestor" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { child: { name: 'child name attribute'} } }
    assert_equal 'child name attribute', Child.human_attribute_name('name')
  end

  test "translated model attributes with ancestors fallback" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { person: { name: 'person name attribute'} } }
    assert_equal 'person name attribute', Child.human_attribute_name('name')
  end

  test "translated model attributes with attribute matching namespaced model name" do
    I18n.backend.store_translations 'en', activemodel: { attributes: {
      person: { gender: 'person gender'},
      :"person/gender" => { attribute: 'person gender attribute' }
    } }

    assert_equal 'person gender', Person.human_attribute_name('gender')
    assert_equal 'person gender attribute', Person::Gender.human_attribute_name('attribute')
  end

  test "translated deeply nested model attributes" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { :"person/contacts/addresses" => { street: 'Deeply Nested Address Street' } } }
    assert_equal 'Deeply Nested Address Street', Person.human_attribute_name('contacts.addresses.street')
  end

  test "translated nested model attributes" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { :"person/addresses" => { street: 'Person Address Street' } } }
    assert_equal 'Person Address Street', Person.human_attribute_name('addresses.street')
  end

  test "translated nested model attributes with namespace fallback" do
    I18n.backend.store_translations 'en', activemodel: { attributes: { addresses: { street: 'Cool Address Street' } } }
    assert_equal 'Cool Address Street', Person.human_attribute_name('addresses.street')
  end

  test "translated model names" do
    I18n.backend.store_translations 'en', activemodel: { models: { person: 'person model' } }
    assert_equal 'person model', Person.model_name.human
  end

  test "translated model names with sti" do
    I18n.backend.store_translations 'en', activemodel: { models: { child: 'child model' } }
    assert_equal 'child model', Child.model_name.human
  end

  test "translated model names with ancestors fallback" do
    I18n.backend.store_translations 'en', activemodel: { models: { person: 'person model' } }
    assert_equal 'person model', Child.model_name.human
  end

  test "human does not modify options" do
    options = { default: 'person model' }
    Person.model_name.human(options)
    assert_equal({ default: 'person model' }, options)
  end

  test "human attribute name does not modify options" do
    options = { default: 'Cool gender' }
    Person.human_attribute_name('gender', options)
    assert_equal({ default: 'Cool gender' }, options)
  end
end

