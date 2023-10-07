# frozen_string_literal: true

class Molecule < ActiveRecord::Base
  belongs_to :liquid, optional: true
  has_many :electrons

  accepts_nested_attributes_for :electrons
end
