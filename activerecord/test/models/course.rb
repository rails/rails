require_dependency 'models/arunit2_model'

class Course < ARUnit2Model
  belongs_to :college
  has_many :entrants
end
