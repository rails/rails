class Student < ApplicationRecord
  has_and_belongs_to_many :lessons
end
