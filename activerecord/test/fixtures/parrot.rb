class Parrot < ActiveRecord::Base
  has_and_belongs_to_many :pirates
  has_and_belongs_to_many :treasures
  has_many :loots, :as => :looter
end
