class Molecule < ApplicationRecord
  belongs_to :liquid
  has_many :electrons
end
