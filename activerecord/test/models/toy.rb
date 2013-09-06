class Toy < ApplicationModel
  self.primary_key = :toy_id
  belongs_to :pet

  scope :with_pet, -> { joins(:pet) }
end
