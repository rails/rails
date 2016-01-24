class Hotel < ActiveRecord::Base
  has_many :departments
  has_many :chefs, through: :departments
  has_many :cake_designers, source_type: 'CakeDesigner', source: :employable, through: :chefs
  has_many :drink_designers, source_type: 'DrinkDesigner', source: :employable, through: :chefs

  has_many :chef_lists, as: :employable_list
  has_many :mocktail_designers, through: :chef_lists, source: :employable, :source_type => "MocktailDesigner"
end
