# frozen_string_literal: true

class Guitar < ActiveRecord::Base
  has_many :tuning_pegs, index_errors: true
  accepts_nested_attributes_for :tuning_pegs
end
