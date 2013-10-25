class House < ActiveRecord::Base
  has_many :doors
end

class Door < ActiveRecord::Base
  belongs_to :house
  validates :house, presence: true
end