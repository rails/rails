class Aircraft < ActiveRecord::Base
  has_many :engines, :foreign_key => "car_id"
end
