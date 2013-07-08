class ShipPart < ActiveRecord::Base
  belongs_to :ship
  has_many :trinkets, :class_name => "Treasure", :as => :looter
  accepts_nested_attributes_for :trinkets, :allow_destroy => true

  validates :name, presence: true
end