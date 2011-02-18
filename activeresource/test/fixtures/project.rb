# used to test validations
class Project < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  schema do
    string  :email
    string  :name
  end

  validates :name, :presence => true
  validates :description, :presence => false, :length => {:maximum => 10}
  validate :description_greater_than_three_letters

  # to test the validate *callback* works
  def description_greater_than_three_letters
    errors.add :description, 'must be greater than three letters long' if description.length < 3 unless description.blank?
  end
end

