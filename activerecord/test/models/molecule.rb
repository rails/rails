class Molecule < ApplicationModel
  belongs_to :liquid
  has_many :electrons
end
