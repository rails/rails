# frozen_string_literal: true

class Bird < ActiveRecord::Base
  belongs_to :pirate
  validates_presence_of :name

  accepts_nested_attributes_for :pirate

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, if: :cancel_save_from_callback
  def cancel_save_callback_method
    throw(:abort)
  end
end
