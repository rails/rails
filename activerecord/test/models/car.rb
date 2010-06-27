class Car < ActiveRecord::Base
  has_many :engines
  has_many :wheels, :as => :wheelable
end
