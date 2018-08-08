# frozen_string_literal: true

class TuningPeg < ActiveRecord::Base
  belongs_to :guitar
  validates_numericality_of :pitch
end
