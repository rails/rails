class Vehicle < ActiveRecord::Base
  self.abstract_class = true
  default_scope -> { where("tires_count IS NOT NULL") }
end

class Bus < Vehicle
end