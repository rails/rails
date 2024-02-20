# frozen_string_literal: true

class Goal < ActiveRecord::Base
  has_one :state, class_name: "GoalState", dependent: :destroy

  scope :no_state, -> { where.missing(:state).or(left_joins(:state).merge(GoalState.not_set)) }
  scope :no_state_simple_or, -> { where.missing(:state).or(GoalState.not_set) }
  scope :associated_state, -> { where.associated(:state).or(joins(:state).merge(GoalState.not_set)) }
  scope :associated_state_simple_or, -> { where.associated(:state).or(GoalState.not_set) }
end
