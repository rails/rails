class DrinkDesigner < ActiveRecord::Base
  has_one :chef, as: :employable
end
