class Student < ApplicationModel
  has_and_belongs_to_many :lessons
end
