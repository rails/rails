class Zine < ActiveRecord::Base
  has_many :interests, inverse_of: :zine
  accepts_nested_attributes_for :interests
end
