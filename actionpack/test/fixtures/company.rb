class Company < ActiveRecord::Base
  attr_protected :rating
  set_sequence_name :companies_nonstd_seq

  validates_presence_of :name
  def validate
    errors.add('rating', 'rating should not be 2') if rating == 2
  end  
end