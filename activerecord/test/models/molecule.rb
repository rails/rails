class Molecule < ActiveRecord::Base
  belongs_to :liquid
  has_many :electrons
end
