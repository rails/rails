class Molecule < ActiveRecord::Base
  belongs_to :liquid
  has_many :electrons

  accepts_nested_attributes_for :electrons
end
