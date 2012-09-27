class Car < ActiveRecord::Base

  has_many :bulbs
  has_many :foo_bulbs, -> { where(:name => 'foo') }, :class_name => "Bulb"
  has_many :frickinawesome_bulbs, -> { where :frickinawesome => true }, :class_name => "Bulb"

  has_one :bulb
  has_one :frickinawesome_bulb, -> { where :frickinawesome => true }, :class_name => "Bulb"

  has_many :tyres
  has_many :engines, :dependent => :destroy
  has_many :wheels, :as => :wheelable, :dependent => :destroy

  scope :incl_tyres, -> { includes(:tyres) }
  scope :incl_engines, -> { includes(:engines) }

  scope :order_using_new_style,  -> { order('name asc') }

end

class CoolCar < Car
  default_scope { order('name desc') }
end

class FastCar < Car
  default_scope { order('name desc') }
end
