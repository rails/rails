class Pet < ActiveRecord::Base
  attr_accessor :current_user

  self.primary_key = :pet_id
  alias_attribute :OwnerId, :owner_id
  belongs_to :owner, :touch => true
  belongs_to :aliased_owner, foreign_key: :OwnerId, class_name: 'Owner'
  has_many :toys
  has_many :aliased_toys, foreign_key: :PetId

  class << self
    attr_accessor :after_destroy_output
  end

  after_destroy do |record|
    Pet.after_destroy_output = record.current_user
  end
end
