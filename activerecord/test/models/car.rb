class Car < ActiveRecord::Base

  has_many :bulbs
  has_many :foo_bulbs, :class_name => "Bulb", :conditions => { :name => 'foo' }
  has_many :frickinawesome_bulbs, :class_name => "Bulb", :conditions => { :frickinawesome => true }

  has_one :bulb
  has_one :frickinawesome_bulb, :class_name => "Bulb", :conditions => { :frickinawesome => true }

  has_many :tyres
  has_many :engines, :dependent => :destroy
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
  default_scope :order => 'name desc'
end
