require_dependency 'models/arunit2_record'

class Course < ARUnit2Record
  belongs_to :college
  has_many :entrants
end
