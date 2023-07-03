# frozen_string_literal: true

class Skill < ActiveRecord::Base
  belongs_to :human, inverse_of: :skills
  belongs_to :zine, inverse_of: :skills
end
