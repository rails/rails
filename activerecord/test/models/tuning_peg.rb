# frozen_string_literal: true

class TuningPeg < ActiveRecord::Base
  belongs_to :guitar, optional: true
  validates_numericality_of :pitch
end
