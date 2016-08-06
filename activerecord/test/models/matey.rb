class Matey < ActiveRecord::Base
  belongs_to :pirate
  belongs_to :target, :class_name => "Pirate"
end
