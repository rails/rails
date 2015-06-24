class Toy < ActiveRecord::Base
  self.primary_key = :toy_id
  belongs_to :pet

  alias_attribute :PetId, :pet_id
  belongs_to :aliased_pet, foreign_key: :PetId

  scope :with_pet, -> { joins(:pet) }
end
