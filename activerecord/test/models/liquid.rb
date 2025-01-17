# frozen_string_literal: true

class Liquid < ActiveRecord::Base
  self.table_name = :liquid
  has_many :molecules, -> { distinct }

  accepts_nested_attributes_for :molecules
end
