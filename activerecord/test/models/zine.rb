class Zine < ApplicationModel
  has_many :interests, :inverse_of => :zine
end
