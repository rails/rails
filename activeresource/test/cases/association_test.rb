require 'abstract_unit'

require 'fixtures/person'
require 'fixtures/beast'
require 'fixtures/customer'


class AssociationTest < Test::Unit::TestCase
  def setup
    @klass = ActiveResource::Associations::Builder::Association
  end


  def test_validations_for_instance
    object = @klass.new(Person, :customers, {})
    assert_equal({}, object.send(:validate_options))
  end

  def test_instance_build
    object = @klass.new(Person, :customers, {})
    assert_kind_of ActiveResource::Reflection::AssociationReflection, object.build
  end

  def test_valid_options
    assert_raise ArgumentError do 
      @klass.build(Person, :customers, {:soo_invalid => true})
    end
  end

  def test_association_class_build
    assert_kind_of ActiveResource::Reflection::AssociationReflection, @klass.build(Person, :customers, {})
  end

  def test_has_many
    External::Person.send(:has_many, :people)
    assert_equal 1, External::Person.reflections.select{|name, reflection| reflection.macro.eql?(:has_many)}.count
  end

  def test_has_one
    External::Person.send(:has_one, :customer)
    assert_equal 1, External::Person.reflections.select{|name, reflection| reflection.macro.eql?(:has_one)}.count
  end
end
