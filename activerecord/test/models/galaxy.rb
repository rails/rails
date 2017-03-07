class Galaxy < ActiveRecord::Base
  belongs_to :universe
  has_many :stars
end
