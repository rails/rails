require 'abstract_unit'

require 'fixtures/person'
require 'fixtures/customer'



class ReflectionTest < Test::Unit::TestCase

  def test_correct_class_attributes
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {})
    assert_equal :people, object.name
    assert_equal :test, object.macro
    assert_equal({}, object.options)
  end

  def test_correct_class_name_matching_without_class_name
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {})
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_string
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => 'Person'})
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_symbol
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => :person})
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_class
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => Person})
    assert_equal Person, object.klass
  end

  def test_correct_class_name_matching_as_string_with_namespace
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => 'external/person'})
    assert_equal External::Person, object.klass
  end

  def test_creation_of_reflection
    object = Person.create_reflection(:test, :people, {})
    assert_equal ActiveResource::Reflection::AssociationReflection, object.class
    assert Person.reflections[:people].present?
    assert_equal Person, Person.reflections[:people].klass
  end

end
