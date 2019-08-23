# frozen_string_literal: true

class DeleteAssociationParent < ActiveRecord::Base
  has_one :da_has_one, dependent: :background_delete
  has_many :da_has_many, dependent: :background_delete
  has_many :da_join, dependent: :background_delete
  has_many :da_has_many_through, through: :da_join, dependent: :background_delete
end
