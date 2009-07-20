$:.push "activesupport/lib"
$:.push "activemodel/lib"

require "active_model/validations"
require "active_model/deprecated_error_methods"
require "active_model/errors"
require "active_model/naming"

class Person
  include ActiveModel::Validations
  extend ActiveModel::Naming
  
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
  
  def to_model() self end
end

person1 = Person.new
p person1.valid?
person1.errors

person2 = Person.new(:name => "matz")
p person2.valid?