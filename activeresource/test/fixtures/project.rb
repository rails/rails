# used to test validations
class Project < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"

  validates_presence_of :name
  validate :description_greater_than_three_letters

  # to test the validate *callback* works
  def description_greater_than_three_letters
    errors.add :description, 'must be greater than three letters long' if description.length < 3 unless description.blank?
  end


  # stop-gap accessor to default this attribute to nil
  # Otherwise the validations fail saying that the method does not exist.
  # In future, method_missing will be updated to not explode on a known
  # attribute.
  def name
    attributes['name'] || nil
  end
  def description
    attributes['description'] || nil
  end
end

