class Speedometer < ApplicationModel
  self.primary_key = :speedometer_id
  belongs_to :dashboard

  has_many :minivans
end
