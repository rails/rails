class Car < ActiveRecord::Base

  has_many :bulbs
  has_many :tyres
  has_many :engines
  has_many :wheels, :as => :wheelable

  scope :incl_tyres, includes(:tyres)
  scope :incl_engines, includes(:engines)

  scope :order_using_new_style,  order('name asc')
  scope :order_using_old_style,  :order => 'name asc'

end

class CoolCar < Car
  default_scope :order => 'name desc'
end

class FastCar < Car
  default_scope order('name desc')
end
