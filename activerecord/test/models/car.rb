class Car < ActiveRecord::Base
  has_many :bulbs
  has_many :tyres
  has_many :engines
  has_many :wheels, :as => :wheelable

  scope :incl_tyres, includes(:tyres)
  scope :incl_engines, includes(:engines)

end
