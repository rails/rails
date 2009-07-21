require 'activemodel'

class Person
  include ActiveModel::Conversion
  include ActiveModel::Validations

  validates_presence_of :name

  attr_accessor :name

  def initialize(attributes = {})
    @name = attributes[:name]
  end

  def persist
    @persisted = true
  end

  def new_record?
    @persisted
  end
end

person1 = Person.new
p person1.valid?
person1.errors

person2 = Person.new(:name => "matz")
p person2.valid?
