require 'abstract_unit'

require 'fixtures/person'
require 'fixtures/customer'



class ReflectionTest < Test::Unit::TestCase
  def setup
  end

  def test_correct_class_attributes
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {})
    assert_equal object.name, :people
    assert_equal object.macro, :test
    assert_equal object.options, {} 
  end

  def test_correct_class_name_matching_without_class_name
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {})
    assert_equal object.klass, Person
  end

  def test_correct_class_name_matching_as_string
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => 'Person'})
    assert_equal object.klass, Person
  end

  def test_correct_class_name_matching_as_symbol
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => :person})
    assert_equal object.klass, Person
  end

  def test_correct_class_name_matching_as_class
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => Person})
    assert_equal object.klass, Person
  end

  def test_correct_class_name_matching_as_string_with_namespace
    object = ActiveResource::Reflection::AssociationReflection.new(:test, :people, {:class_name => 'external/person'})
    assert_equal object.klass, External::Person
  end

  def test_creation_of_reflection
    object = Person.create_reflection(:test, :people, {})
    assert_equal object.class, ActiveResource::Reflection::AssociationReflection
    assert_equal Person.reflections.count, 1
    assert_equal Person.reflections[:people].klass, Person
  end

end
