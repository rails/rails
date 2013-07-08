class Bird < ActiveRecord::Base
  belongs_to :pirate
  validates :name, presence: true

  accepts_nested_attributes_for :pirate

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, :if => :cancel_save_from_callback
  def cancel_save_callback_method
    false
  end
end
