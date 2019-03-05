# frozen_string_literal: true

class Violin < ActiveRecord::Base
  has_many :tuning_pegs, index_errors: :string_number
  accepts_nested_attributes_for :tuning_pegs
end
