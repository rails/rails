class Zine < ActiveRecord::Base
  has_many :interests, inverse_of: :zine
end
