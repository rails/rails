# frozen_string_literal: true

class PetTreasure < ActiveRecord::Base
  self.table_name = 'pets_treasures'

  belongs_to :pet
  belongs_to :treasure
end
