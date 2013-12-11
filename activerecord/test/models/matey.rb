class Matey < ApplicationRecord
  belongs_to :pirate
  belongs_to :target, :class_name => 'Pirate'
end
