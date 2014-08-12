require 'active_model/global_identification'

class Person
  include ActiveModel::GlobalIdentification

  attr_reader :id

  def self.find(id)
    new(id)
  end

  def initialize(id)
    @id = id
  end

  def ==(other_person)
    other_person.is_a?(Person) && id.to_s == other_person.id.to_s
  end
end
