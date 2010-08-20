class Bulb < ActiveRecord::Base
  
  default_scope :conditions => {:name => 'defaulty' }
  
  belongs_to :car

end
