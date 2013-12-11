class Zine < ApplicationRecord
  has_many :interests, :inverse_of => :zine
end
