class Person
  class RecordNotFound < StandardError; end

  include GlobalID::Identification

  attr_reader :id

  def self.find(id)
    raise RecordNotFound.new("Cannot find person with ID=404") if id.to_i == 404
    new(id)
  end

  def initialize(id)
    @id = id
  end

  def ==(other_person)
    other_person.is_a?(Person) && id.to_s == other_person.id.to_s
  end
end
