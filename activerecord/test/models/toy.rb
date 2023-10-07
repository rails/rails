# frozen_string_literal: true

class Toy < ActiveRecord::Base
  self.primary_key = :toy_id
  belongs_to :pet, optional: true

  has_many :sponsors, as: :sponsorable, inverse_of: :sponsorable

  scope :with_pet, -> { joins(:pet) }
end
