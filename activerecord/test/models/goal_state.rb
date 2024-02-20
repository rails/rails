# frozen_string_literal: true

class GoalState < ActiveRecord::Base
  belongs_to :goal

  scope :set, -> { where.not(state: nil) }
  scope :not_set, -> { where(state: nil) }
end
