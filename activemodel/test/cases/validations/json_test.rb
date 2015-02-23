require 'cases/helper'

require 'models/person'

class JsonValidationTest < ActiveModel::TestCase

  def teardown
    Person.clear_validators!
  end

  def test_json_validation_on_non_json_data
    Person.validates_json_of(:details, include: [:address])

    person = Person.new
    person.details = 'not_json'

    assert_raise TypeError do
      assert person.invalid?
    end
  end

  def test_json_validation_on_json_data
    Person.validates_json_of(:details, include: [:address])

    person = Person.new
    person.details = { 'address' => 'funny street' }

    assert person.valid?
  end

  def test_include_option
    Person.validates_json_of(:details, include: [:address])

    person1 = Person.new
    person2 = Person.new

    person1.details = { 'address' => 'funny street' }
    person2.details = { 'phone_number' => '+13435564534' }

    assert person1.valid?
    assert person2.invalid?
  end

  def test_format_option
    Person.validates_json_of(:details,
                             format: { phone_number: { with: /\+[0-9]+/ },
                                       name: { with: /[a-zA-Z]+\s[a-zA-Z]+/ } })

    person1 = Person.new
    person2 = Person.new
    person3 = Person.new

    person1.details = { 'name' => 'Roronoa Zoro', 'phone_number' => '324234' }
    person2.details = { 'phone_number' => '+13435564534', 'name' => 'Luffy' }
    person3.details = { 'name' => 'Nico Robin',
                        'phone_number' => '+35345345' }

    assert person1.invalid?
    assert person2.invalid?
    assert person3.valid?
  end

  def test_each_option
    Person.validates_json_of(:details, each: { include: [:name] })

    person1 = Person.new
    person2 = Person.new

    person1.details = [{ name: 'Zoro' }, { name: 'Luffy' }]
    person2.details = [{ name: 'Zoro' }, { age: 20 }]


    assert person1.valid?
    assert person2.invalid?
  end
end
