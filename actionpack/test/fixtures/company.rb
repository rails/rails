class Company < ActiveRecord::Base
  has_one :mascot
  self.sequence_name = :companies_nonstd_seq

  validates_presence_of :name
  def validate
    errors.add("rating", "rating should not be 2") if rating == 2
  end
end
