# frozen_string_literal: true

class Speedometer < ActiveRecord::Base
  self.primary_key = :speedometer_id
  belongs_to :dashboard, optional: true

  has_many :minivans
end
