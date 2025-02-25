# frozen_string_literal: true

class Pet < ActiveRecord::Base
  attr_accessor :current_user

  self.primary_key = :pet_id
  belongs_to :owner, touch: true
  has_many :toys
  has_many :custom_toys, -> { joins(:sponsors).merge(Sponsor.left_joins(:sponsor_club).where(sponsor_club: { name: "123" }).or(Sponsor.left_joins(:sponsor_club).where(sponsor_club: { name: "" }))) }, class_name: "Toy"
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
