class Pet < ActiveRecord::Base

  attr_accessor :current_user

  set_primary_key :pet_id
  belongs_to :owner, :touch => true
  has_many :toys

  after_destroy do |record|
    $after_destroy_callback_output = record.current_user
  end

end
