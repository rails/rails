require_dependency 'models/arunit2_model'

class College < ARUnit2Model
  has_many :courses
end
