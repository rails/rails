require_dependency 'models/arunit2_record'

class College < ARUnit2Record
  has_many :courses
end
