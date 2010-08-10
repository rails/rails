class Speedometer < ActiveRecord::Base
  set_primary_key :speedometer_id
  belongs_to :dashboard
end