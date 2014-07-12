class Hotel < ActiveRecord::Base
  has_many :departments
  has_many :chefs, through: :departments
  has_many :cake_designers, source_type: 'CakeDesigner', source: :employable, through: :chefs
  has_many :drink_designers, source_type: 'DrinkDesigner', source: :employable, through: :chefs
end
