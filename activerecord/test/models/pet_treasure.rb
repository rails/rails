# frozen_string_literal: true

class PetTreasure < ActiveRecord::Base
  self.table_name = "pets_treasures"

  belongs_to :pet, optional: true
  belongs_to :treasure, optional: true
end
