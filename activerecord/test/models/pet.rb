class Pet < ActiveRecord::Base
  attr_accessor :current_user

  self.primary_key = :pet_id
  belongs_to :owner, :touch => true
  has_many :toys
  has_many :pet_treasures
  has_many :treasures, through: :pet_treasures
  has_many :persons, through: :treasures, source: :looter, source_type: "Person"

  class << self
    attr_accessor :after_destroy_output
  end

  after_destroy do |record|
    Pet.after_destroy_output = record.current_user
  end
end
