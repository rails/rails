# frozen_string_literal: true

class Goal < ActiveRecord::Base
  has_one :state, class_name: "GoalState", dependent: :destroy

  scope :no_state, -> { where.missing(:state).or(left_joins(:state).merge(GoalState.not_set)) }
end
