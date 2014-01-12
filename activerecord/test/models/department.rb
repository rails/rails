class Department < ActiveRecord::Base
  has_many :chefs
  belongs_to :hotel
end
