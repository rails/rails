# frozen_string_literal: true

class Zine < ActiveRecord::Base
  has_many :interests, inverse_of: :zine
  has_many :polymorphic_humans, through: :interests, source_type: "Human"
end
