class Hamster < ActiveRecord::Base
  belongs_to :breeder
  validates :breeder, presence: true
end
