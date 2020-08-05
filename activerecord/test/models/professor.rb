# frozen_string_literal: true

require "models/arunit2_model"

class Professor < ARUnit2Model
  has_and_belongs_to_many :courses
end
