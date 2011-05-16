
require 'abstract_unit'

require 'fixtures/person'
require 'fixtures/beast'
require 'fixtures/customer'


class ActiveResource::Associations::Builder::BelongsToTest < Test::Unit::TestCase
  def setup
    @klass = ActiveResource::Associations::Builder::BelongsTo
  end


  def test_validations_for_instance
    object = @klass.new(Person, :customer, {})
    assert_equal({}, object.send(:validate_options))
  end

  def test_instance_build
    object = @klass.new(Person, :customer, {})
    Person.expects(:defines_belongs_to_finder_method).with(:customer, Customer, 'customer_id')
    assert_kind_of ActiveResource::Reflection::AssociationReflection, object.build
  end


  def test_valid_options
    assert @klass.build(Person, :customer, {:class_name => 'Person'})
    assert @klass.build(Person, :customer, {:foreign_key => 'person_id'})

    assert_raise ArgumentError do
      @klass.build(Person, :customer, {:soo_invalid => true})
    end
  end
end
