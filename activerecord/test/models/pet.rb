class Pet < ActiveRecord::Base

  attr_accessor :current_user

  self.primary_key = :pet_id
  belongs_to :owner, :touch => true
  has_many :toys

  class << self
    attr_accessor :after_destroy_output
  end

  after_destroy do |record|
    Pet.after_destroy_output = record.current_user
  end

end
