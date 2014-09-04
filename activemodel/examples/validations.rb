require File.expand_path('../../../load_paths', __FILE__)
require 'active_model'

class Person
  include ActiveModel::Conversion
  include ActiveModel::Validations

  validates :name, :age, :company, presence: true
  validates :company, length: { minimum: 5 }
  validates :age, numericality: true, allow_blank: true

  attr_accessor :name, :age, :company

  def initialize(attributes = {})
    @name = attributes[:name]
    @age = attributes[:age]
    @company = attributes[:company]
  end

  def persist
    @persisted = true
  end

  def persisted?
    @persisted
  end
end

person1 = Person.new
p person1.valid? # => false
p person1.errors.messages # => {:name=>["can't be blank"], :age=>["can't be blank"], :company=>["can't be blank", "is too short (minimum is 5 characters)"]}

person2 = Person.new(name: 'matz', age: "not integer")
p person2.valid? # => false
p person2.errors.messages # => {:company=>["can't be blank", "is too short (minimum is 5 characters)"], :age=>["is not a number"]}

person3 = Person.new(name: 'matz', company: "rails")
p person3.valid? # => false
p person3.errors.messages # => {:age=>["is not a number"]}

person4 = Person.new(name: 'matz', age: 30, company: "rails")
p person4.valid? # => true