class Minivan < ActiveRecord::Base
  set_primary_key :minivan_id

  belongs_to :speedometer
  has_one :dashboard, :through => :speedometer

  attr_readonly :color

end
