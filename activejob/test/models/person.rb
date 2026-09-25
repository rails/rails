# frozen_string_literal: true

class Person
  class RecordNotFound < StandardError; end

  include GlobalID::Identification

  attr_reader :id

  class << self
    def find(id)
      raise RecordNotFound.new("Cannot find person with ID=404") if id.to_i == 404
      raise "Connection error" if id.to_i == 500

      new(id)
    end

    def where(id:)
      ids = Array(id)
      raise "Connection error" if ids.any? { |value| value.to_i == 500 }
      ids.filter_map { |value| new(value) unless value.to_i == 404 }
    end
  end

  def initialize(id)
    @id = id
  end

  def ==(other_person)
    other_person.is_a?(Person) && id.to_s == other_person.id.to_s
  end
end
