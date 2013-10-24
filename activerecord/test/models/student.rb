class Student < ActiveRecord::Base
  has_and_belongs_to_many :lessons
  belongs_to :record, class_name: 'Ship'
end
